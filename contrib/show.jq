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

def show($prefix):

  def hat:
    if .focused then "▶" else " " end +
    (.id | hex | pad(8)) + " ";

  def head:
    if .type == "root" then
      "<root>"
    elif .type == "output" then
      "<output> \(.name)"
    elif .type == "workspace" then
      "<workspace> \(.name) [\(.layout)]"
    elif .layout != "none" then
      "<tile> [\(.layout)]"
    else
      "<\(.app_id | truncate(20))> \(.name | truncate(10))"
    end;

  def tail:
    [.nodes[], .floating_nodes[]] |
    if . != [] then [
      (.[:-1].[] | hat + $prefix + "├─" + show($prefix + "│ ")),
      (.[-1]     | hat + $prefix + "└─" + show($prefix + "  "))
    ] end |
    join("\n");

  tail as $tail |
  if $tail == "" then
    "─ " + head + $tail
  else
    if $prefix == "" then hat + "┍" else "┮" end + "━━ " +
    head + "\n" + $tail
  end;

def show:
  show("");

ipc::get_tree | show
