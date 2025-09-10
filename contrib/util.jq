module {
  name: "util",
  description: "Utility functions."
};

# Find the index of the first item satisfying the condition in an array
def indexl(condition):
  . as $x | first(range(length) | select($x[.] | condition)) // null;

# Find the negative index of the last item satisfying the condition
def indexr(condition):
  . as $x | first(range(length) | -1 - . | select($x[.] | condition)) // null;

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

def pad($n):
  " " * ($n - length) + .;

def truncate($n):
  if length > $n then
    "\(.[0:$n / 2 | floor])…\(.[-($n / 2 | ceil) + 1:])"
  end;
