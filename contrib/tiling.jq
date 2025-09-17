module {
name: "tiling",
description: "Seamless and customizable dynamic tiling.",
help:
"The overflow layout is a very general tiling strategy that encompasses common
layouts such as master-stack and fibonacci, but that fits a much broader range
of tiling approaches.

In short, each container follows a *schema* that tells it to accommodate at
most N child containers. Any one of those children may, in turn, follow their
own subschema, and so on. As one container fills up, new windows will spill
over into the next container, according to some predetermined priority.

A key consideration in the design of this script is that it must be seamless.
That is, no assumptions must be made about the state of the layout tree before
the script takes effect, and we try to avoid any moments of flickering as
windows move into place."
};

import "builtin/ipc" as ipc;
import "builtin/con" as con;
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


###############################################################################
# Assignment

# A schema is an object. This filter adds default values for each key.
def _assign_defaults:

  # The layout of this container
  .layout |= (
    . // "splith" |
    . as $x |
    if any("splith", "splitv", "tabbed", "stacked"; . == $x) | not then
      error
    end) |

  .priority |= (. // 0) |

  # If the capacity of a schema is greater than 1 but there are no subschemas,
  # then new windows added to this container will appear at the end. If this is
  # set to true, they are added at the beginning.
  .reversed |= (. // false) |

  # The number of nodes that can be accommodated by this container.
  .subschemas[]? |= _assign_defaults;

# Add `.capacity` key to each schema (and check that already stated capacity
# does not conflict with this)
def _assign_capacity:
  if .subschemas then
    .subschemas[] |= _assign_capacity |
    (.subschemas | map(.capacity) | add) as $capacity |
    if $capacity < 1 then
      "Capacity must be above 0" |
      error
    elif .capacity | not then
      .capacity = $capacity
    elif .capacity != $capacity then
      "Stated capacity \(.capacity) does not match calculated capacity \($capacity)" |
      error
    end
  elif .capacity | not then
    .capacity = 1
  end;

# Add `.windows` and `.insert` point to all subschemas on this level. According
# to the priority, position and capacity of each subschema, we (1) assign a
# partition of windows and (2) determine whether any newly opened window should
# appear there.
def _assign_subschema_windows($container):
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

# Each occupied subschema should have a 'representative'. This is a container
# that already exists in the tiling tree, and that will act *as if* it is the
# container that will hold the windows assigned to the schema. Ideally, this
# would be an existing container that already (mostly) corresponds to the
# schema, but if we can't find an appropriate one, not to worry: we can safely
# pick an arbitrary leaf container, as it will be split into a fresh container.
def _assign_subschema_representative($container):
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
        select(con::find(.id == $sub.windows[0].id))
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

def assign:
  _assign_defaults |
  _assign_capacity |
  if .subschemas then
    _assign_subschema_windows |
    _assign_subschema_representative
  end;

###############################################################################
# Applying

# Assume a schema such that it and all its subschemas satisfy the following:
# - The integer at `.occupancy` is the number of windows assigned to this
# schema (guaranteed to be at or below `.capacity`)
# - Windows have been assigned at the `.windows` key
# - The boolean at `.insert` says whether the next future window should appear
# as a descendant of the corresponding container.
#
# Now, we generate commands for setting the insert/swap marks to put the next
# future window in the correct spot. We can always put new windows after leaf
# containers, or at the end of non-leaf containers, (by setting the insert mark),
# or before leaf containers (by setting both the insert and swap marks).
#
# Therefore, the only time any windows other than the new window will be
# shuffled around, is when the new window is put between two non-leaf
# containers, or at the beginning of a container before a non-leaf container.
# (minimizing the reordering even in this case is a TODO)
def _apply_insertion_marks($schema):
  $schema |
  if .subschemas then
    .subschemas |
    (util::index_of(.insert) // empty) as $target |
    # If there is already something in the container, we handle it downstream
    if .[$target].occupancy > 0 then
      .[$target] | _apply_insertion_marks($schema)
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
def _apply_split($layout):
  if .layout == "none" then 
    "[con_id=\(.id)] split toggle",
    "[con_id=\(.id)] layout \($layout)"
  elif .layout != $layout then
    "[con_id=\(.nodes[0].id)] layout \($layout)"
  else
    empty
  end;

# C
def _apply_movement($targets):
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

# Arrange a workspace or container into an overflow-layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared.
# Therefore, we make sure that, at each step, we only access the container's id
# and the attributes of any child that is not (and does not have any
# descendants of) a container that may have already moved.
def apply($schema; $root_schema; $marked):
  . as $container |
  ($schema |
    .windows |= (. // [$container | con::leaves]) |
    if has("subschemas") then 
      _assign_windows |
      _assign_representative($container) |
      .containers = [.subschemas[].representative]
    else
      .containers = .windows
    end) as $schema |
  _apply_insertion_marks($schema),
  _apply_split($schema.layout),
  _apply_movement($schema.containers),
  ( .subschemas.[]? |
    select(.occupancy > 0) |
    . as $subschema |
    .representative |
    apply($subschema; $root_schema; $marked)
  );

def apply($schema):
  if .type == "workspace" then
    if .nodes != [] then
      .nodes[0]
    else
      empty
    end
  end |
  # con::find(.marks | any(. == INSERT)) as $insert |
  # con::find(.marks | any(. == SWAP)) as $swap |
  ($schema | _assign_defaults) as $schema |
  apply($schema; $schema; false);


###############################################################################
# Main loop

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
        con::focused(.type == "workspace") |
        # If the workspace is now entirely empty, we just need to make sure that any
        # new window opened won't appear in some other workspace.
        if .nodes | length == 0 then
          "unmark \(SWAP); unmark \(INSERT)"
        else
          apply($schema)
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
      priority: 1
    },
    { name: "stack",
      capacity: infinite,
      layout: "splitv",
      priority: 2
    }
  ]
});

master_stack
