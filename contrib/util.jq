module {
  name: "util",
  description: "Utility functions."
};

# The first index so that the corresponding array item satisfies the condition
def index_of(condition; index_generator):
  . as $arr | first(index_generator | select($arr[.] | condition)) // null;

def index_of(condition):
  index_of(condition; range(length));

# Find the index of the first item satisfying the condition in an array
def indexl(condition):
  index_of(condition);

# Find the negative index of the last item satisfying the condition
def indexr(condition):
  index_of(condition; range(length) | 1 - .);

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
