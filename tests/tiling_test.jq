import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "tree" as tree;

def create_windows($n):
    (range($n) |
    ipc::run_command("exec foot -c /dev/null -d none /bin/cat")),
    sleep(1)
;

def poc_test:
    (ipc::get_tree | tree::show | stderr),
    create_windows(3),
    ("* * *" | stderr),
    (ipc::get_tree | tree::show | stderr)
;
