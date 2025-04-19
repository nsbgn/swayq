module {
  name: "workspace",
  description: "Page through existing workspaces and the first empty workspace."
};

# Previous solutions: <https://www.reddit.com/r/swaywm/comments/qo9uxr/always_having_an_empty_workspace/>

import "builtin/ipc" as ipc;
import "builtin/tree" as tree;

# Find the index of the first item satisfying the condition in an array
def indexl(condition):
  . as $x | first(range(length) | select($x[.] | condition)) // null;

# In a list of monotonically increasing integers, find the missing integers
def intermediates:
  foreach .[] as $x ({a: .[0], b: .[0]}; {a: .b, b: $x}; range(.a + 1; .b));

# Find the free workspaces.
def free:
  if . == null then ipc::get_workspaces end |
  map(.num) | range(1; .[0]), intermediates, .[-1] + 1;

# Extend the list of occupied workspaces plus an empty workspace
def extend_with_free_workspace:
  if any(.focus == []) | not then
    first(free) as $free |
    (indexl(.num >= $free) // length) as $i |
    .[:$i] + [{num: $free}] + .[$i:]
  end;

def neighbour($offset):
  ipc::get_workspaces |# sort_by(.num) |
  (.[] | select(.focused).output) as $output |
  map(select(.output == $output)) |
  extend_with_free_workspace |
  .[(indexl(.focused) + $offset) % length].num |
  {num: ., output: $output};

def focus_neighbour($offset):
  neighbour($offset) as {$num, $output} |
  ipc::run_command("workspace number \($num); move workspace to \($output)");

def move_to_neighbour($offset):
  neighbour($offset) as {$num, $output} |
  ipc::run_command("move workspace \($num); workspace number \($num); move workspace to \($output)");

def prev: focus_neighbour(-1);
def next: focus_neighbour(1);
