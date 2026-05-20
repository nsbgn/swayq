module {
  name: "rotate",
  summary: "Rotate the active display."
};

import "builtin/ipc" as ipc;

def rotation:
  $ARGS.positional[0] as $arg |
  if $arg == null then
    error("No argument provided!")
  elif $arg == "auto" then
    # TODO fix
    exec(["stdbuf", "-o0", "monitor-sensor", "--accel"])
    | capture(".*orientation changed: (?<orientation>.+)$") |
    .orientation |
    if . == "normal" then
      0
    elif . == "left-up" then
      90
    elif . == "right-up" then
      270
    elif . == "bottom-up" then
      180
    else
      empty
    end
  elif $arg == "up" then
    0
  elif $arg == "right" then
    90
  elif $arg == "down" then
    180
  elif $arg == "left" then
    270
  else
    (if $arg == "ccw" then 270 elif $arg == "cw" then 90 end) as $rot |
    (.transform | if . == "normal" then 0 else tonumber end) as $cur |
    (($cur+$rot)%360)
  end |
  # end |
  tostring
;

ipc::get_outputs.[] |
  select(.active) |
  ipc::run_command("output \(.name) transform \(rotation)")

