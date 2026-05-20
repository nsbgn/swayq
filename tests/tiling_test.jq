import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "tree" as tree;
import "tiling" as tiling;
import "tiling/fibonacci" as fib;
import "tiling/master-stack" as ms;

def inspect:
  { capacity,
    occupancy,
    insert,
    representative: .representative.id,
    windows: [.windows[]? | .id],
    subschemas: [.subschemas[]? | inspect]};

def create_windows($n):
    (range($n) |
    ipc::run_command("exec foot -c /dev/null -d none /bin/cat")),
    sleep(1)
;

def poc_test:
    create_windows(3),
    tiling::apply(fib::schema),
    sleep(0.3),
    (ipc::get_tree | tree::show | stderr)
;
