# Print a readable tiling tree. This should become the default view!
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
    "output \(.name)"
  elif .type == "workspace" then
    "workspace \(.name) \(layout)"
  elif .layout != "none" then
    "tile \(layout)"
  else
    "[\(.app_id)] \(.name | truncate(30))"
  end;

def show($pre; $next; $cur; $f):
  (tree::focus_child.id // null) as $focus |
  (.floating_nodes[-1] // .nodes[-1]).id as $last |
  (.id | hex | pad(8)) + $pre + $cur + container,
  ((.nodes[], .floating_nodes[]) |
    if .id == $last then
      if $f and .id == $focus then
        show($pre + $next; "   "; " ┗━╸"; true)
      else
        show($pre + $next; "   "; " └─╴"; false)
      end
    else
      if $f then
        if .id == $focus then
          show($pre + $next; " │ "; " ┡━╸"; true)
        else
          show($pre + $next; " ┃ "; " ┠─╴"; false)
        end
      else
        show($pre + $next; " │ "; " ├─╴"; false)
      end
    end
  );

def show:
  show(""; ""; ""; true);

ipc::get_tree | show
