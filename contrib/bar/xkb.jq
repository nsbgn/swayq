module {
  name: "bar/xkb"
};

import "builtin/ipc" as ipc;
import "xkb" as xkb;

def blocks:
  xkb::current, xkb::listen |
  [{full_text: .}];

def onclick:
  if .button == 1 then
    ipc::run_command("input type:keyboard xkb_switch_layout next")
  end;


