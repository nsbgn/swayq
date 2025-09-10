# A module for seamless and easily configurable dynamic tiling in Sway/i3.
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
import "builtin/con" as tree;

def schema_base: {
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
  # TODO: Determine from workspace
  layout: "splith",

  # The schema for the child's overflow node, if not the same as the root.
  # TODO: Multiple overflows may be given here, in order of priority.
  # TODO: Make the inheritance explicit and allow finite overflows.
  overflow: null
};

def schema_overflow: {
  capacity: 2,
  layout: "splith",
  insert: "first",
  overflow: {
    position: 0,
    capacity: 3,
    layout: "splitv",
    insert: "first",
    overflow: {
      position: -1,
      capacity: infinite,
      layout: "tabbed"
    }
  }
};

def schema_master_stack: {
  capacity: 2,
  layout: "splith",
  insert: "last",
  overflow: {
    capacity: infinite,
    layout: "splitv",
    insert: "first"
  }
};

def schema_fibonacci: {
  capacity: 2,
  position: 0,
  layout: "splith",
  insert: "after",
  overflow: {
    position: -1,
    layout: "splitv",
    insert: "after",
    overflow: {
      position: -1,
      layout: "splith",
      insert: "before",
      overflow: {
        position: 0,
        layout: "splitv",
        insert: "before"
      }
    }
  }
};

def INSERT: "insert"; # The mark to which to send new windows
def SWAP: "swap"; # The mark with which to swap new windows
def TMP: "tmp"; # Temporary mark

def do:
  if . == [] then
    empty
  else
    join(";") |
    (. | split(";")) as $cmd |
    ipc::run_command(.) as $result |
    ( range($cmd | length) |
      $result[.] as $x |
      "\(if $x.success then "\t" else "ERROR\t" end)\($cmd[.])",
      if $x.error then "\t\($x.error)" else empty end
    ),
    "* * *"
  end;

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

# Normalize a workspace or container into an n-capacity layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared. We make sure that,
# at each step, we can access the container's id and the attributes of any
# child that is not (and does not have any descendants of) a container that may
# have already moved (i.e. a leader).
def normalize($schema; $root_schema; $marked; $leaves):
  # if .type != "con" then "Can only normalize containers." | error end |

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

  # Check if the insertion node can be found on this level; otherwise we will
  # try our luck with the overflows later on. This is guaranteed to be a leaf.
  if $marked then
    null
  else
    if $insert == "first" then
      $before[0]
    elif $insert == "last" then
      $after[-1]
    else
      ($before[], $after[] | select(.focused)) // null
    end
  end as $to_be_marked |
  ($marked or $to_be_marked != null) as $marked |

  if $to_be_marked != null then
    $to_be_marked |
    mark(INSERT; true),
    mark(SWAP; any("first", "before"; $insert == .))
  else
    empty
  end,

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
  ($overflow_node // empty |
  normalize($subschema; $root_schema; $marked; $overflows));

def normalize($schema):
  [tree::leaves] as $leaves |
  if .type == "workspace" then
    if .nodes != [] then
      .nodes[0]
    else
      empty
    end
  end |
  (schema_base + $schema) as $schema |
  normalize($schema; $schema; false; $leaves);

def init:
  # To instantly put new tiling windows where they belong, without a moment of 
  # flickering as the script responds to events, we start by putting in place 
  # rules to insert new windows after the window with the `INSERT` mark. To put 
  # it *before* that window, also set the `SWAP` mark.
  "for_window [tiling] move container to mark \(INSERT)",
  "for_window [tiling] swap container with mark \(SWAP)";

def main($initial_schema):
  ([init] | do),
  foreach ipc::subscribe(["workspace", "window", "tick"]) as $e (
    $initial_schema;
    .;
    # if $e.event == "tick" then
    #   {stack: .stack, payload: $e.payload}
    # end;
    . as $schema |
    if ($e.event == "window" and any("new", "close", "focus"; $e.change == .))
        or ($e.event == "workspace" and $e.change == "focus") then
      [ ipc::get_tree |
        tree::focused(.type == "workspace") |

        # If the workspace is now entirely empty, we just need to make sure that any
        # new window opened won't appear in some other workspace.
        if .nodes | length == 0 then
          "unmark \(SWAP); unmark \(INSERT)"
        else
          normalize($schema)
        end
      ] | do
    else
      empty
    end
  );

def fibonacci:
  main(schema_fibonacci);

def master_stack:
  main(schema_master_stack);

def overflow:
  main(schema_overflow);
