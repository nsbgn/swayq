# Automatically exit full screen mode when a new window opens
# Inspired by <https://old.reddit.com/r/swaywm/comments/vclww6/exit_fullscreen_when_new_window_opens/>

import "i3jq@ipc" as ipc;
import "i3jq@tree" as tree;

ipc::subscribe(["window"])
| if .change == "new" then
    ipc::get_tree
    | tree::focus
    | if .fullscreen_mode then
        ipc::run_command("[con_id=\(.id)] fullscreen disable")
      end
  end
