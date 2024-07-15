# Print a readable tiling tree. This should become the default view!

import "i3jq@ipc" as ipc;

def hex:
  (. / 16 | floor | if . > 0 then hex else "" end)
  + "0123456789abcdef"[. % 16];

def pad($n):
  " " * ($n - length) + .;

def truncate($n):
  if length > ($n | abs) then
    if $n > 0 then
      "\(.[0:$n - 1])…"
    else
      "…\(.[length + $n:length - 1])"
    end
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
    "┊"
  elif .type == "output" then
    "🖥️  \(.name)"
  elif .type == "workspace" then
    "\(layout) workspace \(.name)"
  elif .layout != "none" then
    "\(layout) tile"
  else
    "<\(.app_id | truncate(20))> \(.name | truncate(10))"
  end;

# cf. <https://en.wikipedia.org/wiki/Box_Drawing>
# │├└┬┃┠─┡━┱┗┮┍┐
def show($pile; $next; $cur):
  (.id | hex | pad(8)) + " " + $pile + $cur + container, (
    [.nodes[], .floating_nodes[]] |
    if . != [] then
      (.[:-1].[] | show($pile + $next; "│ "; "├─")),
      (.[-1]     | show($pile + $next; "  "; "└─"))
    else
      empty
    end);

def show:
  show(""; ""; "");

ipc::get_tree | show
