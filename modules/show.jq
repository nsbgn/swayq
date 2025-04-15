module {
  name: "show",
  description: "A module to show a readable tiling tree. This is the default module."
};

# cf. <https://en.wikipedia.org/wiki/Box_Drawing>

import "builtin/ipc" as ipc;
import "builtin/tree" as tree;
import "builtin/ansi" as ansi;

def hex:
  (. / 16 | floor | if . > 0 then hex else "" end)
  + "0123456789abcdef"[. % 16];

def pad($n):
  " " * ($n - length) + .;

def truncate($n):
  ($n / 2 | floor) as $m |
  if length > $n then
    "\(.[0:$m - 2])(…)\(.[length - $m + 1:length])"
  end;

def show(head; tail):
  def layout:
    {splith: "H", splitv: "V", tabbed: "T", "stacked": "S"}[.layout];

  def node:
    if .type == "root" then " - "
    elif .type == "output" then " o "
    elif .type == "workspace" then " \(layout) "
    elif .layout != "none" then "·\(layout)·"
    else ""
    end;

  def show_aux($prefix; $prefix_child; $prefix_parent; $on_focus_path):
    (tree::focused_child.id // null) as $focus_id |
    (.floating_nodes[-1] // .nodes[-1]).id as $last_id |
    "\(head)\($prefix)\($prefix_parent)\(node | ansi::invert) \(tail // "")",
    foreach (.nodes[], .floating_nodes[]) as $node (
      # Init:
      $on_focus_path;
      # Update:
      . and $node.id != $focus_id;
      # Extract:
      . as $prefocus |
      $node |
      ($on_focus_path and .id == $focus_id) as $focus |
      [ if .id != $last_id then
          if $focus      then "│", "┡"
          elif $prefocus then "┃", "┠"
          else                "│", "├"
          end
        else
          " ",
          if $focus then "┗" else "└" end
        end,
        if .type == "floating_con" then
          if $focus then "┅┅" else "┄┄" end
        else
          if $focus then "━━" else "──" end
        end
      ] as [$x, $y, $z] |
      show_aux($prefix + $prefix_child; " \($x)  "; " \($y)\($z)"; $focus)
    );

  show_aux(""; ""; ""; true);
def show(tail):
  show(" "; tail);

def show:
  def head: .id | if . < 2147483646 then tostring else "·" end | pad(5) + " ";
  def tail:
    if .type == "root" then
      ""
    elif .type == "output" then
      "output \(.name)" | ansi::bold
    elif .type == "workspace" then
      "workspace \(.name)" | ansi::bold
    elif .layout != "none" then
      "tile"
    else
      "[\(.app_id | ansi::italic)] \(.name | truncate(30))"
    end;
  show(head; tail);

def watch:
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | ansi::clear, ansi::curpos(1; 1), show;

def watch(tail):
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | ansi::clear, ansi::curpos(1; 1), show(tail);

ipc::get_tree | show
