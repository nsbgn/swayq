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
import "util" as util;

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

def insert_after: mark(INSERT; true);
def insert_before: mark(INSERT; true), mark(SWAP; true);

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

def defaults:
  # The proportion of space to be dedicated to this container compared to other
  # containers.
  .size |= (. // 1) |

  # The layout of this container
  # TODO: Determine from workspace
  .layout |= (
    . // "splith" |
    . as $x |
    if any("splith", "splitv", "tabbed", "stacked"; . == $x) |
    not then
    error
    end) |

  .priority |= (. // 0) |

  # New nodes are usually added at the end. If this is set to true, they are
  # added at the beginning.
  .reversed |= (. // false) |

  # The number of nodes that can be accommodated by this container.
  _calculate_capacity

  # The 
;

# Assume a schema that has been assigned `.windows` and that has been
# appropriately marked with `.insert`. Now generate commands for generating the
# marks that will put the next future window in the correct spot.
# We put marks to put it before or after a window with a capacity of one,
# so the only time any reordering should take place is when we want to put
# a window between two non-leaf containers. (minimizing the reordering even
# in this case is a TODO)
def _commands_for_adding_insertion_marks($schema):
  $schema |
  if has("subschemas") then
    .subschemas |
    (util::index_of(.insert) // empty) as $target |
    # If there is already something in the container, we handle it downstream
    if .[$target].occupancy > 0 then
      .[$target] | _commands_for_adding_insertion_marks($schema)
    # But if it is still empty, we must put the insertion mark on one of the
    # existing windows
    else
      .[util::index_of(.occupancy > 0; range($target; -1; -1))] as $before |
      .[util::index_of(.occupancy > 0; range($target; length))] as $after |
      if ($after != null) and ($before == null or
            ($before.capacity != 1 and $after.capacity == 1)) then
        $after.windows[-1] | insert_before
      elif $before != null then
        $before.windows[0] | insert_after
      else
        "unmark \(SWAP); unmark \(INSERT)"
      end
    end
  else
    if .reversed then
      .windows[0] | insert_before
    else
      .windows[-1] | insert_after
    end
  end;

# If the current container is a leaf, split it according to the schema, so that
# it can be used as a container.
def _commands_for_splitting_leaf_container($layout):
  if .layout == "none" then 
    "[con_id=\(.id)] split toggle",
    "[con_id=\(.id)] layout \($layout)"
  elif .layout != $layout then
    "[con_id=\(.nodes[0].id)] layout \($layout)"
  else
    empty
  end;

# C
def _commands_for_moving_containers($targets):
  . as $container |
  # TODO be smarter about this
  if [.nodes[].id] != [$targets[].id] then
    "[con_id=\(.id)] mark --add \(TMP)", (
      $targets |
      if $container.layout == "none" then
        reverse
      end |
      .[] |
      select(.id != $container.id) |
      "[con_id=\(.id)] move to mark \(TMP)"
    ),
    "[con_id=\(.id)] unmark \(TMP)"
  else
    empty
  end;

# Add `.windows` and `.insert` point to all subschemas on this level. According
# to the priority, position and capacity of each subschema, we (1) assign a
# partition of windows and (2) determine whether any newly opened window should
# appear there.
def _subschemas_assign_windows:
  .windows as $windows |
  .subschemas |= (
    # Remember the position of each subschema
    [foreach .[] as $sub (-1; . + 1; . as $p | $sub | .position = $p)] |
    # TODO: This should become a `group_by` so that we can spread leaves over
    # multiple containers if they have the same priority
    sort_by(.priority | if .reversed then -. end)
    # Go over each child container in order of priority and remember how many
    # of the leaves they should accommodate
    [foreach .[] as $sub (
      {
        remaining: $windows | length,
        occupancy: 0,
        before_insert: true,
        insert: false 
      };
      # TODO break out later
      .occupancy = fmax(fmin(.remaining; $sub.capacity); 0) |
      .insert = (.before_insert and .occupancy < $sub.capacity) |
      .before_insert = (.before_insert and (.insert | not)) |
      .remaining -= .occupancy;
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
  );

def _subschemas_find_representative($container):
  # Each occupied subschema should have a 'representative'. This is a
  # container that will hold all the windows assigned to that subschema.
  # Ideally, this would be an existing container that already mostly
  # corresponds to the schema, but if we can't find an appropriate one, not
  # to worry: we can safely pick an arbitrary leaf container, as it will
  # be split into a fresh container.
  .subschemas |= [foreach .[] as $sub (
    # Init
    [];
    # Update
    . as $ids |
    . + [
    if $sub.occupancy < 1 then
      empty
    # Schemas with capacity 1 are always represented simply by the occupant
    elif $sub.capacity == 1 then
      $sub.windows[0]
    # map each occupied container schema to an unused container on this
    # level, or otherwise to an arbitrary leaf
    else
      first(
        $container |
        .nodes[] |
        # The representative container must not have been previously picked
        select(.id as $id | any($ids[]; . == $id) | not) |
        # And it must also have at least one of the assigned windows, so that
        # we can be sure that the container still exists
        select(tree::find(.id == $sub.windows[0].id))
        # TODO Think about how to pick the container so as to need the
        # smallest number of Sway commands. You could find an optimal
        # assignment by mapping each subschema to a container such that the
        # overlap between assigned windows and already present windows is
        # maximised. But that seems overkill --- it's better to just make
        # an educated guess as to where a new window would mess things up.
      ) // $sub.windows[0]
    end | .id]
    ;
    # Extract
    .[-1] as $new |
    $sub |
    .representative = $new
  )];

# Normalize a workspace or container into an n-capacity layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared.
# Therefore, we make sure that, at each step, we only access the container's id
# and the attributes of any child that is not (and does not have any
# descendants of) a container that may have already moved.
def normalize($schema; $root_schema; $marked):
  . as $container |
  ($schema |
    .windows |= (. // [$container | tree::leaves]) |
    if has("subschemas") then 
      _subschemas_assign_windows |
      _subschemas_find_representative($container) |
      .containers = [.subschemas[].representative]
    else
      .containers = .windows
    end) as $schema |
  _commands_for_adding_insertion_marks($schema),
  _commands_for_splitting_leaf_container($schema.layout),
  _commands_for_moving_containers($schema.containers),
  ( .subschemas // empty |
    .[] |
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
  # tree::find(.marks | any(. == INSERT)) as $insert |
  # tree::find(.marks | any(. == SWAP)) as $swap |
  ($schema | defaults) as $schema |
  normalize($schema; $schema; false);

def init:
  # To instantly put new tiling windows where they belong, without a moment of 
  # flickering as the script responds to events, we start by putting in place 
  # rules to insert new windows after the window with the `INSERT` mark. To put 
  # it *before* that window, also set the `SWAP` mark.
  "for_window [tiling] move container to mark \(INSERT)",
  "for_window [tiling] swap container with mark \(SWAP)",
  "unmark \(INSERT)",
  "unmark \(SWAP)";

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
      [
        ipc::get_tree |
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

def master_stack: main({
  layout: "splith",
  nodes: [
    { name: "master",
      priority: 1},
    { name: "stack",
      capacity: infinite,
      layout: "splitv",
      priority: 2
    }
  ]
});

master_stack
