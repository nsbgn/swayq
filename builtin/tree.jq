module {name: "tree"};

import "i3jq/util" as util;

# `some` is a helper for writing succinct predicates. It returns true if and
# only if any of the values in the argument generator were true. Consider
# `some(.layout == ("stacked", "tabbed"))` or `some(.marks[] == "m")`.
# This is equivalent to `[generator] | any`, but more convenient.
def some(generator):
  first(generator | select(.) | true) // false;

# Descend tree structure one level, into the nth focused node from the given 
# node generator (typically .nodes[] or .floating_nodes[])
def focus_step(generator; $n):
  nth($n; .focus[] as $id | generator | select(.id == $id) // empty);

# Descend tree structure one level, into the nth focused node
def focus_step($n):
  # We assume that the nth item in the focus list exists among the nodes
  .focus[$n] as $id
  | .floating_nodes[], .nodes[]
  | select(.id == $id);

def focus_step:
  focus_step(0);

# Descend the focused containers until arriving at a container that satisfies
# the given condition. For example, to find the focused workspace, do
# `focus(.type == "workspace")`.
def focus(cond):
  until(cond; focus_step);

# Descend the focused containers until arriving at a leaf
def focus:
  focus(.nodes == [] and .floating_nodes == []);

# Descend one level into a neighbour of the nth focused tiling node
def focus_neighbour($offset; $wrap; $n):
  nth($n; .focus[] as $id | .nodes | util::indexl(.id == $id) // empty) as $i
  | ($i + $offset) as $j
  | .nodes
  | .[if $wrap then util::wrap($j) else util::clip($j) end];

# Descend one level into a neighbour of the most focused tiling node
def focus_neighbour($offset; $wrap):
  focus_neighbour($offset; $wrap; 0);

# Find a unique node
def find(condition):
  first(recurse(.nodes[], .floating_nodes[]) | select(condition)) // null;

# Find all nodes that satisfy a condition
def find_all(condition):
  recurse(.nodes[], .floating_nodes[]) | select(condition);

# Find scratchpad workspace from root node
def scratchpad:
  .nodes[] | select(.name == "__i3") | .nodes[0];

# All tiled leaf nodes in the given container
def tiles:
  recurse(.nodes[]);

# All leaf nodes in the given container
def leaves:
  recurse(.nodes[], .floating_nodes[]);
