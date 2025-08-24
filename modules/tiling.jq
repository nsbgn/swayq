# A module for seamless and easily configurable dynamic tiling in Sway/i3.
#
# The n-capacity layout is a generalization of layouts such as master-stack and
# fibonacci. In it, a container follows a schema that tells it to accommodate
# at most $n$ child leaves (growing either forward or backward, and inserting
# new windows either in front or in the back) until the next one is split and
# additional windows spill into this 'overflow container'. This container, in
# turn, follows its own schema, and so on. If there is no suitable overflow
# container, the window will go to a new workspace.
#
# A key consideration in the design is that it must be seamless. That is, no
# assumptions must be made about the state of the layout tree before the script
# takes effect, and we try to avoid moments of flickering as windows move into
# place.

import "builtin/ipc" as ipc;
import "builtin/tree" as tree;

def schema_base: {
  # The number of nodes at which an overflow split is created
  # This is `infinite`
  # The number of nodes that can be accommodated by this container. This is
  # usually calculated.
  capacity: infinite,

  # The proportion of space to be dedicated to this container compared to other
  # containers.
  size: 1,

  # Where should new nodes be inserted if this container gets to choose?
  # Possible values are "before" and "after", being relative to the focused
  # container, or "first" and "last", relative to the current container.
  #insert: "after",

  # At what position in the parent's container should this overflow be placed?
  # Can be an index number from 0 to the parent's $capacity-1 (or -1 to
  # -$capacity when counting from the end)
  #position: -1,

  # The layout of this container
  # TODO: Determine from workspace
  layout: "splith",

  # The schema for the child's overflow node, if not the same as the root.
  # TODO: Multiple overflows may be given here, in order of priority.
  # TODO: Make the inheritance explicit and allow finite overflows.
  content: null
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

# def master_stack: {
#   layout: "splith",
#   nodes: [
#     {},
#     { capacity: infinite,
#       priority: -1,
#       layout: "splitv"
#     }
#   ]
# };

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


def defaults:
  .size |= (. // 1) |
  .layout |= (. // "splith") |
  .reversed |= (.reversed // false) |
  _calculate_capacity
;

def _calculate_capacity:
  if has("subschemas") then
    .subschemas[] |= _calculate_capacity |
    (.subschemas | map(.capacity) | add) as $capacity |
    if has("capacity") | not then
      .capacity = $capacity
    elif .capacity != $capacity then
      "Stated capacity \(.capacity) does not match calculated capacity \($capacity)" |
      error
    end
  elif has("capacity") | not then
    .capacity = 1
  end;

# Assume a schema that has been assigned `.windows` and that has been
# appropriately marked with `.insert`. Now generate commands for generating the
# marks that will put the next future window in the correct spot.
def _commands_insertion_marks:
  if .subschemas == null then
    if .reversed then
      .windows[-1] | insert_after
    else
      .windows[0] | insert_before
    end
  else
    .subschemas |
    (util::index_of(.insert) // empty) as $target |
    # If there is already something in the container, we handle it there
    if .[$target].occupancy > 0 then
      .[$target] | _commands_insertion_marks
    # Otherwise
    else
      .[util::index_of(.occupancy > 0; range($target; -1; -1))] as $before |
      .[util::index_of(.occupancy > 0; range($target; length))] as $after |
      if
        ($after != null) and (
         $before == null or ($before.capacity != 1 and $after.capacity == 1)
         )
      then
        $after.windows[0] | insert_before
      elif $before != null
        $before.windows[0] | insert_after
      else
        "This cannot happen" | error
      end
    end
;

# Normalize a workspace or container into an n-capacity layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared.
# Therefore, we make sure that, at each step, we only access the container's id
# and the attributes of any child that is not (and does not have any
# descendants of) a container that may have already moved.
def normalize($schema; $root_schema; $marked):
  ($schema.windows // [tree::leaves] as $windows) |
  . as $container |

  # TODO: Handle inheriting schemas
  #( $schema | del(.content) + ($subschema // $root_schema) ) as $subschema |

  # Assign each window to one of the subschemas, and also determine where
  # the first upcoming window should go.
  # - Assign a partition of $leaves to each container subschema, according to
  # the priority, position and capacity of each subschema.
  # - Determine for each subschema whether the next opened window should go
  # there. We put marks to put it before or after a window with a capacity of
  # one, so the only time any reordering should take place is when we want to
  # put a window between two non-leaf containers. (minimizing the reordering
  # even in this case is a TODO)
  .subschemas |= (
    # Remember the position of each item
    [foreach .[] as $sub (-1; . + 1; . as $p | $sub | .position = $p)] |
    # TODO: This should become a `group_by` so that we can spread leaves over
    # multiple containers if they have the same priority
    sort_by(.priority)
    # Go over each child container in order of priority and remember how many
    # of the leaves they should accommodate
    [foreach .[] as $sub (
      { remaining: $windows | length,
        occupancy: 0,
        before_insert: true,
        insert: false }
      ;
      # Also try breaking out later
      .occupancy = fmax(fmin(.remaining; $sub.capacity); 0) |
      .insert = (.before_insert and .occupancy < $sub.capacity) |
      .before_insert = (.before_insert and (.insert | not)) |
      .remaining -= .occupancy
      ;
      . as {$occupancy, $insert} |
      $sub |
      .occupancy = $occupancy |
      .insert = $insert
    )] |
    sort_by(.position) |
    [foreach .[] as $sub (
      {j: 0};
      . as $previous |
      $sub |
      .i = $previous.j |
      .j = .i + .occupancy |
      .windows = $windows[.i:.j];
      del(.i, .j, .position)
    )]
  ) |

  # Each occupied subschema should have a 'representative'. This is a container
  # that will hold all the windows assigned to that subschema. This can be a
  # currently existing container, but if we can't find an appropriate one, not
  # to worry: we can safely pick an arbitrary window, and it will be split into
  # a container later. That is not ideal, because we want to minimize
  # re-tiling.
  foreach .subschemas[] | select(.occupancy > 0) as $sub (
      []
    ; # Update
      . as $ids |
      . + [
        if $sub.occupancy < 1 then
          $sub
        # Schemas with capacity 1 are always represented simply by the occupant
        if $sub.capacity == 1 then
          $sub.windows[0].id
        # map each occupied container schema to an unused container on this
        # level, or otherwise to an arbitrary leaf
        else
          first(
            $container |
            .nodes[] |
            .id as $id |
            # The representative container must not have been previously picked
            select(.id | in($ids) | not) |
            # And it must also have at least one of the assigned windows, so that
            # we can be sure that the container still exists
            select(tree::find(.id == $s.windows[0]))
            # TODO Think about how to pick the container so as to need the
            # smallest amount of Sway commands.
            # You could make a mapping from windows to containers 
            # You could, of course, map each window to a
            # container that maximises the overlap between assigned windows and
            # already contained windows (and minimizes the amount of windows that
            # have to be moved out) but that seems like it would be a bit
            # overkill. Better is to just guess where a new window would mess up
            # the containers
          ) // $sub.windows[0]
        end
      ; # extract

    ]
  ) |

  # ---
  # From here on out, we generate actual commands!

  _commands_insertion_marks,

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

  # Finally, recursively apply the normalization step to all subschemas.
  (
    .subschemas[] |
    . as $subschema |
    select(.occupancy > 0) |
    .representative |
    normalize($subschema; $root_schema; $marked)
  );

def normalize($schema):
  if .type == "workspace" then
    if .nodes != [] then
      .nodes[0]
    else
      empty
    end
  end |
  ($schema | defaults) as $schema |
  normalize($schema; $schema; false);

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
        tree::find(.marks | any(. == INSERT)) as $insert |
        tree::find(.marks | any(. == SWAP)) as $swap |
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
