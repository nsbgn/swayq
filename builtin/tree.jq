module {
  name: "tree",
  description: "Filters for navigating the layout tree."
};

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

# `lineage` traverses the tree to produce all lists of nodes that are visited
# on the way to the target nodes. The lists are in reverse chronological order.
# `lineage/0` traces the node that is most in focus; `lineage/1` allows you to
# specify a target node, expressed either as a node or as a conditional.
# Finally, `lineage/2` allows you provide the filter to finds child nodes. In
# essence, `lineage` produces a list of ancestors. For example, `lineage[1]` is
# the focused node's parent node.
def lineage(target; child):
  target as $x |
  if $x == true or try ($x.id == .id) catch false then
    [.]
  else
    (child | lineage(target; child)) + [.]
  end;
def lineage(target):
  lineage(target; .nodes[], .floating_nodes[]);
def lineage:
  lineage(isempty(focus_child); focus_child);

# Find scratchpad workspace from root node
def scratchpad:
  .nodes[] | select(.name == "__i3") | .nodes[0];

# All tiled leaf nodes in the given container
def tiles:
  recurse(.nodes[]);

# All leaf nodes in the given container
def leaves:
  recurse(.nodes[], .floating_nodes[]);
