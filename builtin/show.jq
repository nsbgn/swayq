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
def clear: _ansi_escape + "[2J";

def layout:
  .layout |
  if . == "splith" then
    "↔️ "
  elif . == "splitv" then
    "↕️ "
  elif . == "tabbed" then
    "🗂️"
  elif . == "stacked" then
    "📑"
  else . end;

def container:
  if .type == "root" then
    ""
  elif .type == "output" then
    (" O " | invert) + " \(.name | bold)"
  elif .type == "workspace" then
    (" W " | invert) + " \(.name | bold) \(layout)"
  elif .layout != "none" then
    (" T " | invert) + " \(layout)"
  else
    " \(.app_id | italic) \(.name | truncate(30))"
  end;

def show:
  def show_aux($prefix; $prefix_child; $prefix_parent; $on_focus_path):
    ($prefix + $prefix_child) as $prefix_child |
    (tree::focus_child.id // null) as $focus_id |
    (.floating_nodes[-1] // .nodes[-1]).id as $last_id |
    (.id | hex | pad(8)) + $prefix + $prefix_parent + container,
    foreach (.nodes[], .floating_nodes[]) as $node (
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

  show_aux(""; ""; " ┇"; true);

def watch:
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree | clear, show;

ipc::get_tree | show
