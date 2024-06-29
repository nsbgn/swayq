# Print a readable tiling tree

import "i3jq/ipc" as ipc;

def show($prefix):
    def head:
        "#\(.id) \(.app_id) type:\(.type) layout:\(.layout)";

    def tail:
        [ .nodes[], .floating_nodes[]
        | show($prefix + "  ┊ ")] |
        join("\n") |
        if . != "" then "\n" + . end;

    $prefix +
    (if .focused then head | "✱ " + . else head end) +
    tail;

def show:
    show("");

def changing:
    ipc::subscribe(["window", "workspace"]) |
    ipc::get_tree |
    60 * "─" + "\n" + show
;

ipc::get_tree | show
