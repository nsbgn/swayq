package main

import (
	"encoding/binary"
	"encoding/json"
	"os"
	"os/exec"
	"net"
	"log"
)

var endian = binary.NativeEndian

var magic = [6]byte{'i', '3', '-', 'i', 'p', 'c'}

type header struct {
	Magic  [6]byte
	Length uint32
	Type   uint32
}

type message struct {
	Type    uint32
	Payload []byte
}

func (m *message) json() (any, error) {
	var result any
	err := json.Unmarshal(m.Payload, &result)
	if err != nil {
		return nil, err
	}

	// In case the next message is an event, add event type to the object
	isEvent := m.Type >> 31
	if isEvent == 1 {
		obj := result.(map[string]any)
		obj["event"] = eventType(m.Type & 0x7F).String()
		result = obj
	}

	return result, nil
}

type connection struct {
	conn net.Conn
	keep_alive bool
	replies uint
}

func (c *connection) send(msg message) error {
	var n uint32 = 0
	if msg.Payload != nil {
		n = uint32(len(msg.Payload))
	}
	err := binary.Write(c.conn, endian, &header{magic, n, msg.Type})
	if err != nil {
		return err
	}
	if n > 0 {
		err = binary.Write(c.conn, endian, msg.Payload)
		if err != nil {
			return err
		}
	}
	return nil
}

func (c *connection) receive() (message, error) {
	var h header
	if err := binary.Read(c.conn, endian, &h); err != nil {
		return message{}, err
	}
	msg := message{
		Type: h.Type,
		Payload: make([]byte, h.Length),
	}
	err := binary.Read(c.conn, endian, &msg.Payload)
	return msg, err
}

func (c *connection) Next() (any, bool) {
	if c.replies > 0 && !c.keep_alive {
		c.conn.Close()
		return nil, false
	}
	msg, err := c.receive()
	if err != nil {
		return err, true
	}
	c.replies += 1
	json, err := msg.json()
	if err != nil {
		return err, true
	}
	return json, true
}

func get_socket() string {
	socket := os.Getenv("SWAYSOCK")
	if socket != "" {
		return socket
	}

	socket = os.Getenv("I3SOCK")
	if socket != "" {
		return socket
	}

	out, err := exec.Command("i3", "--get-socketpath").Output()
	if err != nil {
		log.Fatalln("could not determine i3 socket")
	}
	return string(out)
}

var socket = get_socket()

func i3q_ipc(msgType int, msg *string, keep_alive bool) (*connection, error) {
	conn, err := net.Dial("unix", socket)
	if err != nil {
		return nil, err
	}
	c := connection{conn, keep_alive, 0}
	t := uint32(msgType)
	if msg == nil {
		err = c.send(message{Type: t})
	} else {
		err = c.send(message{Type: t, Payload: []byte(*msg)})
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}
