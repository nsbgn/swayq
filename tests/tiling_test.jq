import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "tree" as tree;
import "tiling" as tiling;
import "tiling/fibonacci" as fib;
import "tiling/master-stack" as ms;

# Expand short representation of a tree `{splith: [...]}` into the
# representation used by Sway `{layout: "splith", nodes: [...]}` 
def expand_short:
  if type == "object" then
    [ to_entries[] |
      . as {$key, $value} |
      if any("splith", "splitv", "stacked", "tabbed"; $key == .) then
        { key: "layout", value: $key },
        { key: "nodes",
          value: $value | map(
          if type == "string" then {app_id: .} else expand_short end)
        }
      end
    ] |
    from_entries
  end;


# Compare the input object against a reference, such that all values in the
# reference are the same in the input (but not necessarily vice versa).
# Example:
#   { layout: "splitv", nodes: [ { app_id: "A", focused: true } ] }
#   | check({ nodes: [ {app_id: "A" } ]})
# => true
def matches($ref):
  . as $inp |
  $ref |
  if type != ($inp | type) then
    false
  elif type == "object" or type == "array" then
    all(keys[]; . as $k | if in($inp) then $inp[.] | matches($ref[$k]) else true end)
    and if type == "array" then length == ($inp | length) else true end
  else
    . == $inp
  end;


# Removes all keys not appearing in the reference
def prune($ref):
  if type != ($ref | type) then
    .
  elif type == "object" then
    with_entries(. as {$key} | if $key | in($ref) | not then empty else .value |= prune($ref[$key]) end)
  elif type == "array" then
    . as $inp |
    [range(length) | . as $k | $inp[$k] | prune($ref[$k])]
  end;


# Check the current workspace against the reference
def check_ws($short_ref):
  ipc::get_tree |
  ($short_ref | expand_short) as $ref |
  con::focused(.type == "workspace") |
  if matches($ref) then
    empty
  else
    "Unexpected workspace state!\nRef: \($ref)\nGot: \(. | prune($ref))" |
    error
  end;


def spawn_win($id):
  ipc::run_command("exec foot -c /dev/null -d none -a '\($id)' /bin/cat"),
  sleep(1);


def add_win($id; $schema; $expected_state):
  spawn_win($id),
  tiling::tile($schema),
  sleep(1),
  check_ws($expected_state);


def fib_layout_test:
  fib::schema as $fib |
  tiling::init_insertion_marks,
  add_win("A"; $fib; {splitv: ["A"]}),
  add_win("B"; $fib; {splitv: [{splith: ["A", {splitv: ["B"]}]}]})
;
