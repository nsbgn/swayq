module {name: "tree"};

import "i3jq/util" as util;


# Predicates on containers

def is_marked($mark):
  .marks as $marks | $mark | util::among($marks[]);

def is_horizontal:
  .layout | util::among("splith", "tabbed");

def is_vertical:
  .layout | util::among("splitv", "stacked");

def is_pile:
  .layout | util::among("tabbed", "stacked");

def is_leaf:
  .nodes == [] and .layout == "none";

def is_tile:
  .type == "con" and .nodes == [];


# Finding general containers

# Descend tree structure one level, into the nth focused node from the given 
# node generator (typically .nodes[] or .floating_nodes[])
def focus_step_n(generator; $n):
  nth($n; .focus[] as $id | generator | select(.id == $id) // empty);

# Descend tree structure one level, into the nth focused node
def focus_step_n($n):
  # We can assume that the nth item in the focus list exists among the nodes
  .focus[$n] as $id
  | .floating_nodes[], .nodes[]
  | select(.id == $id);

def focus_step:
  focus_step_n(0);

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
  recurse(.nodes[]) | select(is_tile);

# All leaf nodes in the given container
def leaves:
  recurse(.nodes[], .floating_nodes[]);
