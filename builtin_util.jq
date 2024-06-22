module {name: "util"};

# Utility filters

def assert($condition):
  if $condition then . else error("an assertion failed") end;

# Find the index of the first item satisfying the condition in an array
def indexl(condition):
  . as $x | first(range(length) | select($x[.] | condition)) // null;

# Find the negative index of the last item satisfying the condition
def indexr(condition):
  . as $x | first(range(length) | -1 - . | select($x[.] | condition)) // null;

# Is a value among the given values? ie `2 | among(1, 2, 3) == true`
def among(f):
  first(. == f // empty) // false;

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
