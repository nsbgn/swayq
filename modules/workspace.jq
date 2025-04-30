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

# Find the free workspaces. Input: ipc::get_workspaces
def free:
  map(.num) | sort |
  # Having monotonically increasing numbers of workspaces, find those missing…
  foreach .[] as $x ({a: 1, b: 1}; {a: .b, b: $x}; range(.a + 1; .b)),
  # … plus one extra number at the end
  .[-1] + 1;

def neighbour($offset):
  ipc::get_workspaces |
  # Remember the first free workspace
  first(free) as $free |
  # Select only the workspaces on the current output
  (.[] | select(.focused).output) as $output |
  map(select(.output == $output)) |
  # Extend the current list of workspaces with an empty workspace if necessary
  if any(.focus == []) | not then
    (indexl(.num >= $free) // length) as $i |
    .[:$i] + [{num: $free}] + .[$i:]
  end |
  # Select the next workspace in that list
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
