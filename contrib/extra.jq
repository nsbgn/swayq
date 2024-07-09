module {name: "util"};

# Find the index of the first item satisfying the condition in an array
def indexl(condition):
  . as $x | first(range(length) | select($x[.] | condition)) // null;

# Find the negative index of the last item satisfying the condition
def indexr(condition):
  . as $x | first(range(length) | -1 - . | select($x[.] | condition)) // null;

# Is a value among the given values? ie `2 | among(1, 2, 3) == true`
def among(f):
  first(. == f // empty) // false;

# `some` is a helper for writing succinct predicates. It returns true if and
# only if any of the values in the argument generator were true. Consider
# `some(.layout == ("stacked", "tabbed"))` or `some(.marks[] == "m")`.
# This is equivalent to `[generator] | any`, but more convenient.
def some(generator):
  first(generator | select(.) | true) // false;

# Clamp a number to minimum and maximum values
def clamp($min; $max):
  if . >= $min then if . <= $max then . else $max end else $min end;

# Clip a number to minimum and maximum values; empty if outside the values
def clip($min; $max):
  if . >= $min and . <= $max then . else empty end;

# Transform array indices
def wrap($i): $i % length;
def clamp($i): length as $n | $i | clamp(0; $n - 1);
def clip($i): length as $n | $i | clip(0; $n - 1);

# Descend tree structure one level, into the nth focused node from the given 
# node generator (typically .nodes[] or .floating_nodes[])
def focus_child(generator; $n):
  nth($n; .focus[] as $id | generator | select(.id == $id) // empty);

# Descend one level into a neighbour of the nth focused tiling node
def focus_neighbour($offset; $wrap; $n):
  nth($n; .focus[] as $id | .nodes | indexl(.id == $id) // empty) as $i
  | ($i + $offset) as $j
  | .nodes
  | .[if $wrap then wrap($j) else clip($j) end];

# Descend one level into a neighbour of the most focused tiling node
def focus_neighbour($offset; $wrap):
  focus_neighbour($offset; $wrap; 0);
