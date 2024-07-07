# Print a readable tiling tree.

import "i3jq/ipc" as ipc;

def show($prefix):
    def head:
        if .type == "root" then
            "[root:\(.layout)] (#\(.id))"
        elif .type == "output" then
            "[\(.layout)] \(.name) (#\(.id))"
        elif .type == "workspace" then
            "[workspace:\(.layout)] \(.name) (#\(.id))"
        elif .layout != "none" then
            "[con:\(.layout)] (#\(.id))"
        else
            "\(.app_id) (#\(.id)) \(if .focused then "*" else "" end)"
        end;

    def tail:
        [.nodes[], .floating_nodes[]] |
        if . != [] then [
            (.[:-1].[] | $prefix + "├─" + show($prefix + "│ ")),
            (.[-1]     | $prefix + "└─" + show($prefix + "  "))
        ] end |
        join("\n");

    tail as $tail |
    if $tail == "" then
        "╴ " + head + $tail
    else
        "┮━━ " + head + "\n" + $tail
    end;

def show:
    show("");

def listen:
    ipc::subscribe(["window", "workspace"]) |
    ipc::get_tree |
    60 * "─" + "\n" + show
;

ipc::get_tree | show
