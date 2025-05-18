# Seamless and easily configurable dynamic tiling in Sway/i3!
#
# The n-capacity layout is a generalization of layouts such as master-stack and
# fibonacci. In it, a container follows a schema that tells it to accommodate
# at most $n$ child leaves (growing either forward or backward, and inserting
# new windows either in front or in the back) until the next one is split and
# additional windows spill into this 'overflow container'. This container, in
# turn, follows its own schema, and so on. 
#
# A key consideration in the design is that it must be seamless. That is, no
# assumptions must be made about the state of the layout tree before the script
# takes effect, and we try to avoid moments of flickering as windows move into
# place.

import "builtin/ipc" as ipc;
import "builtin/tree" as tree;
import "show" as show;

def base: {
  # The number of nodes at which an overflow split is created
  capacity: infinite,

  # The proportion of space to be dedicated to each node
  size: 1,

  # Where should new nodes be inserted if this container gets to choose?
  # Possible values are "before" and "after", being relative to the focused
  # container, or "first" and "last", relative to the current container.
  insert: "after",

  # At what position in the parent's container should this overflow be placed?
  # Can be an index number from 0 to the parent's $capacity-1 (or -1 to
  # -$capacity when counting from the end)
  position: -1,

  # The layout of this container
  layout: "splith", # TODO: Determine from workspace

  # The schema for the child's overflow node, if not the same as the root
  # schema.
  # TODO: Multiple overflows may be given here, in order of priority.
  overflow: null
};

def master_stack: {
  capacity: 2,
  layout: "splith",
  insert: "after",
  overflow: {
    capacity: infinite,
    layout: "splitv",
    insert: "first"
  }
};

def fibonacci: {
  capacity: 2,
  position: 0,
  layout: "splith",
  insert: "first",
  overflow: {
    position: -1,
    layout: "splitv",
    overflow: {
      position: -1,
      layout: "splith",
      overflow: {
        position: 0,
        layout: "splitv",
      }
    }
  }
};

# The mark to which to send new windows
def INSERT: "insert";
# The mark with which to swap new windows
def SWAP: "swap";
def TMP: "_swayq_overflow_moving";

def do(commands):
  [commands] |
  flatten |
  if . == [] then
    empty
  else
    join(";") |
    (. | split(";")) as $cmd |
    ipc::run_command(.) as $result |
    (
      range($cmd | length) |
      $result[.] as $x |
      "\(if $x.success then "\t" else "ERROR\t" end)\($cmd[.])",
      if $x.error then "\t\($x.error)" else empty end
    ),
    ipc::send_tick(""),
    (ipc::get_tree | show::show)
  end;

def is_event(event; change):
  (.event as $e | any(event; $e == .)) and
  (.change as $c | any(change; $c == .));

def mark($mark; $yes):
  if $yes then
    if .marks | any(. == $mark) | not then
      "[con_id=\(.id)] mark --add \($mark)"
    else
      empty
    end
  else
    "unmark \($mark)"
  end;
def mark($mark):
  mark($mark; true);

def position:
  if . == "top" or . == "left" then 0 # beginning
  elif . == "bottom" or . == "right" then -1 # end
  else "Unknown position '\(.)'" | error end;

def axis:
  if . == "left" or . == "right" then 0 # horizontal axis
  elif . == "bottom" or . == "top" then 1 # vertical axis
  else "Unknown axis '\(.)'" | error end;

# Ensure that all marks are in the correct spot. We can assume that the layout
# is correct here; if it isn't, it will be fixed later.
def ensure_marks($orientation):
  ($orientation | position) as $i |
  (.nodes[0] // empty) |
  (.nodes | length < 2) as $monocle |
  (.nodes[$i] // empty) |
  tree::focused |
  mark(INSERT),
  mark(SWAP; $monocle);

# Normalize a workspace or container into an n-capacity layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared. We make sure that,
# at each step, we can access the container's id and the attributes of any
# child that is not (and does not have any descendants of) a container that may
# have already moved (i.e. a leader).
def normalize($schema; $root_schema; $leaves):
  if .type != "con" then
    "Can only normalize containers." | error
  end |

  $schema as {$capacity, $layout, $insert, overflow: $subschema} |
  ($schema | del(.overflow) + ($subschema // $root_schema)) as $subschema |
  ($leaves | length) as $n |

  # Partition $leaves into $before, $overflows, and $after.
  ($subschema.position % $capacity |
    if . < 0 then [. + $capacity, . + $n + 1]
             else [., . + $n + 1 - $capacity]
    end as $bounds |
    $bounds[0] as $i |
    ($bounds | max) as $j |
    $leaves |
    [.[:$i], .[$i:$j], .[$j:]]
  ) as [$before, $overflows, $after] |

  # Determine the $overflow_node. This is either the first non-leaf child that
  # does not contain any leaf from this level (because we cannot risk it
  # vanishing during our processing), or otherwise an arbitrary $overflow node
  # (in which case it will be used for creating a new split).
  ( first(.nodes[] | select(.layout != "none" and (
      .id as $id | all($before[], $after[]; tree::find(.id == $id) == null))))
    // $overflows[0]
  ) as $overflow_node |

  ($before + [$overflow_node // empty] + $after) as $content |

  # If the current container is a leaf, split it according to the schema.
  if .layout == "none" then 
    "[con_id=\(.id)] split toggle",
    "[con_id=\(.id)] layout \($layout)"
  elif .layout != $layout then
    "[con_id=\(.nodes[0].id)] layout \($layout)"
  else
    empty
  end,

  # If the current container's children are not yet in the correct position,
  # then move all leaders and the $overflow_node (or vice versa) to this
  # container.
  if [.nodes[].id] != [$content[].id] then
    . as $self |
    "[con_id=\(.id)] mark --add \(TMP)", (
      $content |
      if $self.layout == "none" then
        reverse
      end |
      .[] |
      select(.id != $self.id) |
      "[con_id=\(.id)] move to mark \(TMP)"
    ),
    "[con_id=\(.id)] unmark \(TMP)"
  else
    empty
  end,

  # Finally, recursively apply the normalization step to the $overflow_node.
  ($overflow_node // empty | normalize($subschema; $root_schema; $overflows));

def normalize($schema):
  [tree::leaves] as $leaves |
  if .type == "workspace" then
    if .nodes != [] then
      .nodes[0]
    else
      empty
    end
  end |
  (base + $schema) as $schema |
  normalize($schema; $schema; $leaves);

def init:
  # To instantly put new tiling windows where they belong, without a moment of 
  # flickering as the script responds to events, we start by putting in place 
  # rules to insert new windows after the window with the `INSERT` mark. To put 
  # it *before* that window, also set the `SWAP` mark.
  "for_window [tiling] move container to mark \(INSERT)",
  "for_window [tiling] swap container with mark \(SWAP)";

def main($initial_schema):
  do(init),
  foreach ipc::subscribe(["workspace", "window", "tick"]) as $e (
    $initial_schema;
    .;
    # if $e.event == "tick" then
    #   {stack: .stack, payload: $e.payload}
    # end;
    . as $schema | $e |
    if is_event("window"; "new", "close") or is_event("workspace"; "focus") then
      do(
        ipc::get_tree |
        tree::focused(.type == "workspace") |

        # If the workspace is now entirely empty, we just need to make sure that any
        # new window opened won't appear in some other workspace.
        if .nodes | length == 0 then
          "unmark \(SWAP); unmark \(INSERT)"
        else
          normalize($schema)
        end
      )
    elif is_event("window"; "focus") then
      do(
        ipc::get_tree |
        tree::focused(.type == "workspace") |
        empty
        # ensure_marks($schema)
      )
    else
      empty
    end
  );

main(fibonacci)
