module {
  name: "cmd",
  description: "Convenience methods for constructing and running commands."
};

import "builtin/ipc" as ipc;
import "builtin/con" as con;

# Run one or more i3 commands in one IPC message
def run(commands):
  ([commands] | join(";")) as $cmd |
  ipc::run_command($cmd) |
  if any(.success | not) then
    "Command '\($cmd)' had error result: '\(.)'" |
    if env["SWAYQ_DEBUG"] then
      error
    else
      stderr
    end
  else
     empty
  end;


