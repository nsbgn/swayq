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
    "🌳"
  elif .type == "output" then
    "🖥️  \(.name)"
  elif .type == "workspace" then
    "📕 \(layout) \(.name)"
  elif .layout != "none" then
    layout
  else
    "<\(.app_id | truncate(20))> \(.name | truncate(10))"
  end;

# cf. <https://en.wikipedia.org/wiki/Box_Drawing>
# │├└┬┃┠─┡━┱┗┮┍┐
def show($prefix):

  def hat:
    (.id | hex | pad(8));

  def tail:
    if (.nodes == [] and .floating_nodes == []) | not then
      [.nodes[], .floating_nodes[]] |
      [
        (.[:-1].[] | hat + " " + $prefix + "├─" + show($prefix + "│ ")),
        (.[-1]     | hat + " " + $prefix + "└─" + show($prefix + "  "))
      ] | join("\n")
    else
      ""
    end;

  tail as $tail |
  if $tail == "" then
    "─ " + container + $tail
  else
    if $prefix == "" then hat + "┈┬" else "┬" end +
    container + "\n" + $tail
  end;

def show:
  show("");

ipc::get_tree | show
