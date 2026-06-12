module {
  name: "bar/pulseaudio"
};

import "builtin/ipc" as ipc;

def mute:
  first(exec(["pactl", "get-sink-mute", "@DEFAULT_SINK@"])) |
  capture("Mute: (?<mute>(yes|no))") |
  (.mute == "yes");

def volume:
  first(exec(["pactl", "get-sink-volume", "@DEFAULT_SINK@"])) |
  capture("(?<volume>[0-9]+)%") |
  .volume |
  tonumber;

def pulseaudio:
  volume |
  if mute then "\uf6a9"
  elif . < 5 then "\uf026"
  elif . < 50 then "\uf027"
  else "\uf028"
  end as $icon |
  [{full_text: "\($icon) \(.)"}];

def onclick:
  if .button == 1 then
    ipc::run_command("exec pactl set-sink-mute @DEFAULT_SINK@ toggle")
  elif .button == 4 then
    ipc::run_command("exec pactl set-sink-volume @DEFAULT_SINK@ +2%")
  elif .button == 5 then
    ipc::run_command("exec pactl set-sink-volume @DEFAULT_SINK@ -2%")
  end;

def blocks:
  pulseaudio,
  ( exec(["pactl", "subscribe"]) |
    select(test("sink")) |
    pulseaudio
  );
