module {
  name: "tiling",
  description: "Seamless and customizable dynamic tiling.",
};

# Arrange a workspace or container into an overflow-layout. This is a subtler
# affair than it may at first appear, because, for a seamless experience, we
# send all our commands to the window manager in a single IPC message.
# Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared. So we make sure
# that, at each step, we only access the container's id and the attributes of
# any child that is not (and does not have any descendants of) a container that
# may have already moved.

import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "util" as util;

def INSERT: "insert"; # The mark to which to send new windows
def SWAP: "swap"; # The mark with which to swap new windows
def TMP: "tmp"; # Temporary mark

###############################################################################
# Extending the schemas with extra information.

def assign_defaults:
  .layout |= (
    . // "splith" |
    . as $x |
    if any("splith", "splitv", "tabbed", "stacked"; . == $x) | not then
      "'\(.)' is not a valid layout" |
      error
    end) |
  .priority |= (. // 0) |
  .reversed |= (. // false) |
  .subschemas[]? |= assign_defaults;


# Calculate capacity and check for conflicts in explicitly stated capacity
def assign_capacity:
  .subschemas[]? |= assign_capacity |
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


# Add the following keys to the direct subschemas of this schema:
# - The integer at `.occupancy` is the number of windows assigned to this
#   schema (guaranteed to be at or below `.capacity`)
# - An array of windows (of length equal to `.occupancy`) has been assigned at
#   the `.windows` key
# - The boolean at `.insert` says whether the next future window should appear
#   as a descendant of the corresponding container.
def assign_windows_aux:
  .windows as $windows |
  if .subschemas then
    .subschemas |= (
      # Remember the position of each subschema
      [range(length) as $i | .[$i] | .position = $i] |
      # TODO: This should become a `group_by` so that we can spread leaves over
      # multiple containers if they have the same priority
      sort_by(.priority) |

      # Go over each one, in order of priority, to determine how many windows
      # to accommodate and where the next window in line should go
      [foreach .[] as $sub (
        {
          remaining: $windows | length,
          occupancy: 0,
          before_insert: true,
          insert: false 
        }
        ; # Update state
        # TODO break out later
        .occupancy = fmax(fmin(.remaining; $sub.capacity); 0) |
        .insert = (.before_insert and .occupancy < $sub.capacity) |
        .before_insert = (.before_insert and (.insert | not)) |
        .remaining -= .occupancy
        ; # Add calculated information to the subschema
        . as {$occupancy, $insert} |
        $sub |
        .occupancy = $occupancy |
        .insert = $insert
      )] |

      # Now put the schemas back in their original positions and assign the
      # appropriate windows to each
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
  .subschemas[]? |= assign_windows_aux;
def assign_windows($windows):
  .insert = true |
  .occupancy = fmin(.capacity; $windows | length) |
  .windows = $windows[:.occupancy] |
  assign_windows_aux;


# Each occupied subschema is to have a 'representative' container. This is a
# container that already exists in the tiling tree, and that will act as the
# container that carries out the subschema. Ideally, this should be an existing
# container that already (mostly) corresponds to the schema, because it would
# minimize the necessary commands. But in case we can't find an appropriate
# container, we can safely pick an arbitrary *leaf* container from the windows.
# That window will be split into a fresh container.
# Before this filter can be executed, `.windows` and `.occupancy` must have
# been added.
def assign_representative($parent):
  .representative = $parent |
  if .subschemas then
    .subschemas |= [foreach .[] as $sub (
    # Init
      []
    ; # Update the representatives
      . as $others |
      . + [

      # Empty subschemas need no representative
      if $sub.occupancy < 1 then
        null

      # Schemas of capacity 1 are always represented by that single occupant
      elif $sub.capacity == 1 then
        $sub.windows[0]

      # map each occupied container schema to an unused container on this
      # level, or otherwise to an arbitrary leaf
      else
        first(
          # Try an existing node first, and then try any of the leaves
          ($parent.nodes[], $sub.windows[]) |
          # The representative container must not have been previously picked
          # TODO does this make sense?
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
      end]
    ; # Extract
      .[-1] as $repr |
      $sub |
      assign_representative($repr)
    )]
  end;


###############################################################################
# Commands are applied at each level of the schema, recursively

def _cmd_mark($mark): 
  if .marks | any(. == $mark) | not then
    "[con_id=\(.id)] mark --add \($mark)"
  else
    empty
  end;

def _cmd_unmark($mark): 
  "unmark \($mark)";


# Generate commands for setting the insert/swap marks (which ensures the next future
# window appears in the correct spot).
#
# Note that we can perfectly indicate the next window appears if it should
# appear after a leaf container, or at the end of non-leaf containers (by
# setting the insert mark), or before a leaf container (by setting both the
# insert and swap marks). Therefore, the only time we can expect windows to be
# shuffled around, is when the new window is put between two non-leaf
# containers, or at the beginning of a container before a non-leaf container.
# This will happen in the `apply_container_arrangement` step.
def apply_insertion_marks:
  # Only bother if the insert flag is set and the schema is occupied
  if (.insert | not) or .occupancy < 1 then
    empty

  elif .subschemas then
    # Find out which of the subschemas has the insert flag set
    .subschemas |
    util::index_of(.insert) as $target |
    if $target == null then
      "Unexpected: schema with insert flag has no children with insert flag" |
      error
    end |

    # If the corresponding container is non-empty, it will be handled downstream
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

      else
        "Unexpected: schema is occupied but none of its subschemas are" |
        error
      end
    end

  # If there are no defined subschemas, then the container's children are all
  # windows and we can put the marks on the first or last one
  else
    if .reversed then
      .windows[0] | _cmd_mark(INSERT), _cmd_mark(SWAP)
    else
      .windows[-1] | _cmd_mark(INSERT), _cmd_unmark(SWAP)
    end
  end;


# Adjust layout of the representative container to agree with the schema.
def apply_layout:
  . as {$layout, $capacity} |
  .representative |
  if $capacity == 1 then
    empty
  # Leaf windows need to be split so they can be used as a container
  elif .layout == "none" then 
    "[con_id=\(.id)] split toggle",
    "[con_id=\(.id)] layout \($layout)"
  # Layout readjustment needs to be done on a child window for some reason
  elif .layout != $layout then
    "[con_id=\(.nodes[0].id)] layout \($layout)"
  else
    empty
  end;


# This filter moves around the representative containers such that they are in
# the order mandated by the schema, if necessary. This is relevant when (1.) we
# just started the script and the workspace is not yet compliant with the
# layout schema or (2.) a new window has appeared in a spot that weren't able
# to fully control, as described in `apply_insertion_marks`.
def apply_container_arrangement:
  # What are the child containers we expect of this representative?
  if .subschemas then
    .subschemas | map(.representative // .windows[])
  else
    .windows
  end as $ideal |

  .representative |
  . as $repr |

  # If the children of the representative container are not already the ideal
  # containers in the exact same order, we just move them all.
  # TODO be smarter about this to minimize the number of commands required
  if [(.nodes[]? // .).id] != [$ideal[].id] then
    "[con_id=\(.id)] mark --add \(TMP)",

    # If the representative was a leaf, we must do this in reverse order
    # because moving multiple windows to the same leaf has the effect of
    # reversing order.
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


def run(commands):
  ([commands] | join(";")) as $cmd |
  ipc::run_command($cmd) |
  if any(.success | not) then
    "Command '\($cmd)' had error result: '\(.)'" |
    if env["SWAYQ_DEBUG"] then
      error
    else
      stderr
    end
  else
     empty
  end;


def apply($schema):

  def apply_recursively:
    apply_insertion_marks,
    apply_layout,
    apply_container_arrangement,
    (.subschemas[]? | select(.occupancy > 0) | apply_recursively);

  ipc::get_tree |
  con::focused(.type == "workspace") |

  run(
    # If the workspace is empty, we only make sure that any new window opened
    # won't appear in some other workspace.
    if .nodes == [] then
      "unmark \(SWAP)",
      "unmark \(INSERT)"
    else
      [con::leaves] as $windows |
      # The first representative is the already existing first child of the
      # workspace
      .nodes[0] as $repr |
      $schema |
      assign_defaults |
      assign_capacity |
      assign_windows($windows) |
      assign_representative($repr) |
      apply_recursively
    end);


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
  run(init),
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
