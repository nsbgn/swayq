module {name: "tree"};

# Descend tree structure one level, into the nth focused node
def focus_child($n):
  # We assume that the nth item in the focus list exists among the nodes
  .focus[$n] as $id
  | .floating_nodes[], .nodes[]
  | select(.id == $id);

def focus_child:
  focus_child(0);

# Descend the focused containers until arriving at a container that satisfies
# the given condition. For example, to find the focused workspace, do
# `focus(.type == "workspace")`.
def focus(cond):
  until(cond; focus_child);

# Descend the focused containers until arriving at a leaf
def focus:
  focus(.nodes == [] and .floating_nodes == []);

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
