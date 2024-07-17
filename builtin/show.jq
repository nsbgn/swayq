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
    " ┇"
  elif .type == "output" then
    (" O " | invert) + " \(.name | bold)"
  elif .type == "workspace" then
    (" W " | invert) + " \(.name | bold) \(layout)"
  elif .layout != "none" then
    (" T " | invert) + " \(layout)"
  else
    " \(.app_id | italic) \(.name | truncate(30))"
  end;

def show($pre; $next; $cur; $f):
  (tree::focus_child.id // null) as $focus |
  (.floating_nodes[-1] // .nodes[-1]).id as $last |
  (.id | hex | pad(8)) + $pre + $cur + container,
  ((.nodes[], .floating_nodes[]) |
    if .id == $last then
      if $f and .id == $focus then
        show($pre + $next; "    "; " ┗━━"; true)
      else
        show($pre + $next; "    "; " └──"; false)
      end
    else
      if $f then
        if .id == $focus then
          show($pre + $next; " │  "; " ┡━━"; true)
        else
          show($pre + $next; " ┃  "; " ┠──"; false)
        end
      else
        show($pre + $next; " │  "; " ├──"; false)
      end
    end
  );

def show:
  show(""; ""; ""; true);

def watch:
  ipc::subscribe(["window", "workspace"]) |
  ipc::get_tree |
  (_ansi_escape + "[2J"),
  show;

ipc::get_tree | show
