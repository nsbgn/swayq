module {
name: "tiling",
description: "Seamless and customizable dynamic tiling.",
};

import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "util" as util;

def INSERT: "insert"; # The mark to which to send new windows
def SWAP: "swap"; # The mark with which to swap new windows
def TMP: "tmp"; # Temporary mark

# Add default values for each key in the schema object and check that the
# values make sense.
def validate_schema:
  .subschemas[]? |= validate_schema |

  .layout |= (
    . // "splith" |
    . as $x |
    if any("splith", "splitv", "tabbed", "stacked"; . == $x) | not then
      "'\(.)' is not a valid layout" |
      error
    end) |
  .priority |= (. // 0) |
  .reversed |= (. // false) |

  # Add `.capacity` key to each schema (and check that already stated capacity
  # does not conflict with this)
  (try (.subschemas | map(.capacity) | add) // .capacity // 1) as $cap |
  .capacity |= (
    if . and . != $cap then
      "Stated capacity \($cap) does not match calculated capacity \(.)" |
      error
    elif . and . < 1 then
      "Capacity must be above 0" |
      error
    else
      $cap
    end
  );

###############################################################################
# Assigning windows

# Add the following keys to the direct subschemas of this schema:
# - The integer at `.occupancy` is the number of windows assigned to this
#   schema (guaranteed to be at or below `.capacity`)
# - An array of windows (of length equal to `.occupancy`) has been assigned at
#   the `.windows` key
# - The boolean at `.insert` says whether the next future window should appear
#   as a descendant of the corresponding container.
def _assign_placement_aux:
  .windows as $windows |
  if .subschemas then
    .subschemas |= (
      # Remember the position of each subschema
      [range(length) as $i | .[$i] | .position = $i] |
      # TODO: This should become a `group_by` so that we can spread leaves over
      # multiple containers if they have the same priority
      sort_by(.priority) |
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
      [ foreach .[] as $sub
        ( {j: 0}
        ; . as $previous |
          $sub |
          .i = $previous.j |
          .j = .i + .occupancy |
          .windows = $windows[.i:.j]
        ; del(.i, .j, .position)
        )]
    )
  end |
  .subschemas[]? |= _assign_placement_aux;
def _assign_placement($windows):
  .insert = true |
  .occupancy = fmin(.capacity; $windows | length) |
  .windows = $windows[:.occupancy] |
  _assign_placement_aux;


# Each occupied subschema should have a 'representative'. This is a container
# that already exists in the tiling tree, and that will act *as if* it is the
# container that will hold the windows assigned to the schema. Ideally, this
# would be an existing container that already (mostly) corresponds to the
# schema, but if we can't find an appropriate one, not to worry: we can safely
# pick an arbitrary leaf container, as it will be split into a fresh container.
# Before this filter can be executed, `.windows` and `.occupancy` must have
# been added.
def _assign_representative($parent):
  .representative = $parent |
  if .subschemas then
    .subschemas |= [foreach .[] as $sub (
      # Init
      [];

      # Update
      . as $others |
      . + [
      if $sub.occupancy < 1 then
        null
      # Schemas of capacity 1 are always represented by that single occupant
      elif $sub.capacity == 1 then
        $sub.windows[0]
      # map each occupied container schema to an unused container on this
      # level, or otherwise to an arbitrary leaf
      else
        first(
          # Try an existing node first
          ($parent.nodes[], $sub.windows[]) |
          # The representative container must not have been previously picked
          select(.id as $id | any($others[].id; . == $id) | not) |
          # And it must also have at least one of the assigned windows, so that
          # we can be sure that the container still exists
          select(con::find(.id == $sub.windows[0].id))
          # TODO Think about how to pick the container so as to need the
          # smallest number of Sway commands. You could find an optimal
          # assignment by mapping each subschema to a container such that the
          # overlap between assigned windows and already present windows is
          # maximised. But that seems overkill --- it's better to just make
          # an educated guess as to where a new window would mess things up.
        )
      end];

      # Extract
      .[-1] as $repr |
      $sub |
      _assign_representative($repr)
    )]
  end;

###############################################################################
# Applying

def _cmd_mark($mark): 
  if .marks | any(. == $mark) | not then
    "[con_id=\(.id)] mark --add \($mark)"
  else
    empty
  end;

def _cmd_unmark($mark): 
  "unmark \($mark)";

# We generate commands for setting the insert/swap marks to put the next
# future window in the correct spot. We can always put new windows after leaf
# containers, or at the end of non-leaf containers (by setting the insert mark),
# or before leaf containers (by setting both the insert and swap marks).
#
# Therefore, the only time any windows other than the new window will be
# shuffled around, is when the new window is put between two non-leaf
# containers, or at the beginning of a container before a non-leaf container.
# (minimizing the reordering even in this case is a TODO)
def _gen_cmd_insertion_marks:
  # We will only bother if the insert flag is set and the schema is occupied
  if (.insert | not) or .occupancy < 1 then
    empty

  elif .subschemas then
    # Find out which of the subschemas has the insert flag set
    .subschemas |
    (util::index_of(.insert) // empty) as $target |

    # If the corresponding container is non-empty, don't do anything because it
    # will be handled downstream
    if .[$target].occupancy > 0 then
      empty

    # But if it is still empty, we must put the insertion mark on one of the
    # windows on this level
    else
      # We find the occupied containers directly before and after this one
      (try .[util::index_of(.occupancy > 0; range($target; -1; -1))] catch null) as $before |
      (try .[util::index_of(.occupancy > 0; range($target; length))] catch null) as $after |

      # We want to set marks on *windows* rather than containers, so that we
      # can be sure that containers will not have disappeared. We will usually
      # want to put the new window *after* the window before, except when there is
      # no such window, or when putting it before the window after would avoid
      # container reordering.
      if ($after != null) and (
          $before == null or ($before.capacity != 1 and $after.capacity == 1)
        ) then
        $after.windows[-1] | _cmd_mark(INSERT), _cmd_mark(SWAP)
      elif $before != null then
        $before.windows[0] | _cmd_mark(INSERT), _cmd_unmark(SWAP)

      # Any other situation should not be possible, because that would mean
      # that the schema is occupied yet none of its subschemas are occupied
      else
        "Impossible situation occurred" |
        error
      end
    end

  # If there are no defined subschemas, then the container's children are all
  # windows
  else
    if .reversed then
      .windows[0] | _cmd_mark(INSERT), _cmd_mark(SWAP)
    else
      .windows[-1] | _cmd_mark(INSERT), _cmd_unmark(SWAP)
    end
  end;

# If the current container is a leaf, split it according to the schema, so that
# it can be used as a container.
def _gen_cmd_layout:
  . as {$layout, $capacity} |
  .representative |
  if $capacity == 1 then
    empty
  elif .layout == "none" then 
    "[con_id=\(.id)] split toggle",
    "[con_id=\(.id)] layout \($layout)"
  elif .layout != $layout then
    "[con_id=\(.nodes[0].id)] layout \($layout)"
  else
    empty
  end;

def _gen_cmd_movement:
  # The situation as it should be:
  (try (.subschemas | map(.representative // empty)) // .windows) as $ideal |

  .representative |
  . as $repr |

  # TODO be smarter about this
  if [(.nodes[]? // .).id] != [$ideal[].id] then
    "[con_id=\(.id)] mark --add \(TMP)",
    ( if .layout == "none" then
        $ideal |
        reverse
      else
        $ideal
      end |
      .[] |
      select(.id != $repr.id) |
      "[con_id=\(.id)] move to mark \(TMP)"
    ),
    "[con_id=\(.id)] unmark \(TMP)"
  else
    empty
  end;

# Input is a fully assigned schema.
def _gen_cmd:
  _gen_cmd_insertion_marks,
  _gen_cmd_layout,
  _gen_cmd_movement,
  (.subschemas[]? | select(.occupancy > 0) | _gen_cmd);

def do:
  select(. != []) |
  join(";") |
  split(";") as $cmd |
  ipc::run_command(.) as $result |
  range($cmd | length) |
  {command: $cmd[.], result: $result[.]} |
  debug |
empty;

def inspect:
  { capacity,
    occupancy,
    insert,
    representative: .representative.id,
    windows: [.windows[]? | .id],
    subschemas: [.subschemas[]? | inspect]};

# Arrange a workspace or container into an overflow-layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared.
# So we make sure that, at each step, we only access the container's id and the
# attributes of any child that is not (and does not have any descendants of) a
# container that may have already moved.
def apply($schema):
  ipc::get_tree |
  con::focused(.type == "workspace") |

  # If the workspace is empty, we only make sure that any new window opened
  # won't appear in some other workspace.
  if .nodes == [] then
    ["unmark \(SWAP)", "unmark \(INSERT)"]
  else
    [con::leaves] as $windows |
    .nodes[0] as $repr |
    $schema |
    validate_schema |
    _assign_placement($windows) |
    _assign_representative($repr) |
    debug(inspect) |
    [_gen_cmd]
  end |
  do;

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
  apply($initial_schema),
  foreach ipc::subscribe(["workspace", "window", "tick"]) as $e (
    $initial_schema;
    .;
    # if $e.event == "tick" then
    #   {stack: .stack, payload: $e.payload}
    # end;
    . as $schema |
    if ($e.event == "window" and any("new", "close", "focus"; $e.change == .))
        or ($e.event == "workspace" and $e.change == "focus") then
      apply($schema)
    else
      empty
    end
  );
