# Automatically exit full screen mode when a new window opens
# Inspired by <https://old.reddit.com/r/swaywm/comments/vclww6/exit_fullscreen_when_new_window_opens/>

subscribe(["window"])
| if .change == "new" then
    get_tree
    | window
    | if .fullscreen_mode then
        run_command("[con_id=\(.id)] fullscreen disable")
      end
  end;
