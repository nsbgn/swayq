# Predicates on containers

def is_marked($mark):
  .marks as $marks | $mark | among($marks[]);

def is_horizontal:
  .layout | among("splith", "tabbed");

def is_vertical:
  .layout | among("splitv", "stacked");

def is_pile:
  .layout | among("tabbed", "stacked");

def is_leaf:
  .nodes == [] and .layout == "none";

def is_tile:
  .type == "con" and .nodes == [];


# Finding general containers

# Descend tree structure one level, into the nth focused node from the given 
# node generator (typically .nodes[] or .floating_nodes[])
def descend_focus(generator; $n):
  nth($n; .focus[] as $id | generator | select(.id == $id) // empty);

# Descend tree structure one level, into the nth focused node
def descend_focus($n):
  # We can assume that the nth item in the focus list exists among the nodes
  .focus[$n] as $id
  | .floating_nodes[], .nodes[]
  | select(.id == $id);

def descend_focus:
  descend_focus(0);

# Descend one level into a neighbour of the nth focused tiling node
def descend_neighbour($offset; $wrap; $n):
  nth($n; .focus[] as $id | .nodes | indexl(.id == $id) // empty) as $i
  | ($i + $offset) as $j
  | .nodes
  | .[if $wrap then wrap($j) else clip($j) end];

# Descend one level into a neighbour of the most focused tiling node
def descend_neighbour($offset; $wrap):
  descend_neighbour($offset; $wrap; 0);

# Find a unique node
def find(condition):
  first(recurse(.nodes[], .floating_nodes[]) | select(condition)) // null;

# Find all nodes that satisfy a condition
def find_all(condition):
  recurse(.nodes[], .floating_nodes[]) | select(condition);


# Finding specific containers

# Find scratchpad workspace from root node
def scratchpad:
  .nodes[] | select(.name == "__i3") | .nodes[0];

# Descend tree structure until finding focused workspace
def workspace:
  until(.type == "workspace"; descend_focus);

# Follow focus until arriving at a tabbed/stacked container or a leaf window
def pile:
  until(is_pile or is_leaf; descend_focus);

# Find window that would be focused if this container receives focus
def window:
  until(is_leaf; descend_focus);

# All tiled leaf nodes in the given container
def tiles:
  recurse(.nodes[]) | select(is_tile);
