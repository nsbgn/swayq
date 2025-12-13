import "builtin/ipc" as ipc;

def current:
  ipc::get_inputs[] |
  select(.type=="keyboard") |
  .xkb_active_layout_name;

def listen:
  ipc::subscribe(["input"]) |
  if .event == "input" and .input.type == "keyboard" then
    .input.xkb_active_layout_name
  else
    empty
  end;

def switch:
  ipc::run_command("input type:keyboard xkb_switch_layout next");

$ARGS.positional[0] as $A |
if $A == null then
  current, listen
elif $A == "switch" then
  switch
else
  "Unrecognized argument \($A)" | error
end
