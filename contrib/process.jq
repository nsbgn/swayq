module {
  name: "process",
  description: "Add process information to the layout tree"
};

import "builtin/ipc" as ipc;

def process_info:
  [...pid? // empty] |
  unique |
  ["ps", "e", (.[] | "--ppid", tostring), "-o", "ppid=,pid=,tpgid="] |
  exec(.) |
  capture("(?<ppid>[0-9]+)\\s+(?<pid>[0-9]+)\\s+(?<tpgid>[0-9]+)") |
  [exec(["readlink", "-f", "/proc/\(.tpgid)/\("exe", "cwd")"])] as [$exe, $cwd] |
  {pid: .pid | tonumber, $exe, $cwd}
  ;

ipc::get_tree | process_info
