module {
  name: "show",
  description: "A module to show a readable tiling tree. This is the default module."
};

# cf. <https://en.wikipedia.org/wiki/Box_Drawing>

import "i3jq@ipc" as ipc;
import "i3jq@tree" as tree;

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

def _ansi($i):
  "\(_ansi_escape)[\($i)m\(.)\(_ansi_escape)[0m";
def bold: _ansi(1);
def italic: _ansi(3);
def underline: _ansi(4);
def invert: _ansi(7);
def clear: _ansi_escape + "[2J" + _ansi_escape + "[H";

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
    ($prefix + $prefix_child) as $prefix_child |
    (tree::focus_child.id // null) as $focus_id |
    (.floating_nodes[-1] // .nodes[-1]).id as $last_id |
    "\(head)\($prefix)\($prefix_parent)\(node | invert) \(tail // "")",
    foreach tree::children as $node (
      # Init:
      $on_focus_path;
      # Update:
      . and $node.id != $focus_id;
      # Extract:
      . as $waiting_for_focus |
      $node |
      if .id != $last_id then
        if $on_focus_path and .id == $focus_id then
          show_aux($prefix_child; " │  "; " ┡━━"; true)
        elif $waiting_for_focus then
          show_aux($prefix_child; " ┃  "; " ┠──"; false)
        else
          show_aux($prefix_child; " │  "; " ├──"; false)
        end
      else
        if $on_focus_path and .id == $focus_id then
          show_aux($prefix_child; "    "; " ┗━━"; true)
        else
          show_aux($prefix_child; "    "; " └──"; false)
        end
      end
    );

  show_aux(""; ""; ""; true);
def show(tail):
  show(" "; tail);

def show:
  def head: .id | hex | pad(8) + " ";
  def tail:
    if .type == "root" then
      ""
    elif .type == "output" then
      "output \(.name)" | bold
    elif .type == "workspace" then
      "workspace \(.name)" | bold
    elif .layout != "none" then
      "tile"
    else
      "\(.app_id | italic) - \(.name | truncate(30))"
    end;
  show(head; tail);

def watch:
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | clear, show;

def watch(tail):
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | clear, show(tail);

ipc::get_tree | show
