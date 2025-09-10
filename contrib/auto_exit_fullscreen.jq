# Automatically exit full screen mode when a new window opens
# Inspired by <https://old.reddit.com/r/swaywm/comments/vclww6/exit_fullscreen_when_new_window_opens/>

import "builtin/ipc" as ipc;
import "builtin/con" as con;

ipc::subscribe(["window"]) |
if .change == "new" then
  ipc::get_tree |
  con::focused |
  if .fullscreen_mode then
    ipc::run_command("[con_id=\(.id)] fullscreen disable")
  end
end
