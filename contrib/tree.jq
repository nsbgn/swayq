module {
  name: "viz",
  description: "A module to show a readable ASCII visualisation of the layout tree."
};

# cf. <https://en.wikipedia.org/wiki/Box_Drawing>

import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "builtin/ansi" as ansi;

def show(head; tail):
  def show_aux($prefix; $prefix_child; $prefix_parent; $on_focus_path):
    (con::focused_child.id // null) as $focus_id |
    (.floating_nodes[-1] // .nodes[-1]).id as $last_id |
    ("\($prefix)\($prefix_parent)" | ansi::fg("gray")) as $pfx |
    "\(head)\($pfx)\(tail // "")",
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
          if $focus then "┅" else "┄" end
        else
          if $focus then "━" else "─" end
        end
      ] as [$x, $y, $z] |
      show_aux($prefix + $prefix_child; "\($x) "; "\($y)\($z)"; $focus)
    );

  show_aux(""; ""; ""; true);
def show(tail):
  show(" "; tail);

def show:
  def node_type:
    if .type as $type | any("root", "output", "workspace"; . == $type) then
      .type
    elif .layout != "none" then
      .layout
    else
      ""
    end | ansi::fg("gray") | ansi::underline | ansi::bold;

  def head: .id | if . < 2147483646 then tostring else "·" end | util::pad(5) + " ";
  def tail:
    "\(node_type)" +
    if .type == "root" or .type == "output" then
      ""
    elif .type == "workspace" then
      " \(.layout | ansi::fg("gray")) \"\(.name)\""
    elif .layout != "none" then
      ""
    else
      "\(.app_id | util::truncate(16) | ansi::fg("gray")) \"\(.name | util::truncate(16) |
      ansi::italic)\""
    end +
    if .marks != [] then
      " [\(.marks | join(","))]" | ansi::fg("red")
    else
      ""
    end;
  show(head; tail);

def watch:
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | ansi::clear, ansi::curpos(1; 1), show;

def watch(tail):
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | ansi::clear, ansi::curpos(1; 1), show(tail);

ipc::get_tree | show
