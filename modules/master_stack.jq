# The n-overflow layout is a generalization of layouts such as master-stack and
# fibonacci. In it, a container follows a schema that tells it to accommodate
# at most $n$ child leaves (growing either forward or backwards, and inserting
# new windows either at the beginning or at the end) until the next one is
# split and additional windows spill into this 'overflow container'. This
# container, in turn, follows its own schema, and so on. 
#
# A key consideration in the design of this approach to dynamic tiling is that
# it must be seamless. That is, no assumptions must be made about the state of
# the layout tree before the script takes effect, and there must be no moments
# of flickering as the script responds to events and windows move into place.

import "builtin/ipc" as ipc;
import "builtin/tree" as tree;

def default: {
  capacity: infinite,
  size: 0.5,
  forward: true,
  layout: null,
  overflow: null
};

def master_stack: {
  capacity: 2,
  size: 0.5,
  layout: "splith",
  forward: false,
  insertion: true,
  overload: {
    layout: "splitv"
  }
};

def fibonacci: {
  capacity: 2,
  size: 0.5,
  layout: "splith",
  forward: true,
  overload: {
    layout: "splitv"
  }
};

# The mark to which to send new windows
def INSERT: "insert";
# The mark with which to swap new windows
def SWAP: "swap";

def do(commands):
  [commands] |
  flatten |
  if . == [] then
    empty
  else
    join("; ") |
    { command: .,
      result: ipc::run_command(.) }
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

# Normalize a workspace or container into an n-overflow layout. This is a
# subtler affair than it may at first appear, because, for a seamless
# experience, we send all our commands to the window manager in a single IPC
# message. Therefore, we cannot take the input layout tree at face value: some
# containers may have vanished and others may have appeared. We make sure that,
# at each step, we can access the container's id and the attributes of any
# child that is not (and does not have any descendants of) a container that may
# have already moved.
def normalize($schema):
  normalize($schema, [tree::leaves]);
def normalize($schema; $leaves):
  (default + $schema) as {$forward, $capacity, $layout, $overflow} |

  # Organize $leaves into $leaders and $followers, according to the
  # schema's capacity and direction. $followers are those windows that are in
  # the overflow and $leaders are those that are not.
  if $forward then
    [$leaves[:$capacity], $leaves[$capacity:]]
  else
    [$leaves[-$capacity:], $leaves[:-$capacity]]
  end as [$leaders, $followers] |

  # Determine the $overflow_node. This is either the first non-leaf child that
  # does not contain any $leaders, or otherwise the first of the $followers.
  ( first(.nodes[] | select(
      .layout != "none" and
      all($leaders[]; .id as $id | tree::find(.id == $id) == null)))
    // $followers[if $forward then 0 else -1 end]
  ) as $overflow_node |

  if $forward then
    $leaders + [$overflow_node // empty]
  else
    [$overflow_node // empty] + $leaders
  end as $content |

  # If the current container is a leaf, split it according to the schema.
  if .layout != $layout then 
    #TODO
    "[con_id=\(.id)] layout \($layout)"
  else
    empty
  end,

  # If the current container's children are not yet in the correct position,
  # then move all leaders and the $overflow_node (or vice versa) to this
  # container.
  if [.nodes[].id] != [$content[].id] then
    "[con_id=\(.id)] mark --add _swayq_overflow_moving",
    (
      $content[] |
      # TODO
      "[con_id=\(.id)] move to mark _swayq_overflow_moving"
    ),
    "[con_id=\(.id)] unmark _swayq_overflow_moving"
  else
    empty
  end,

  # Finally, recursively apply the normalization step to the $overflow_node.
  ($overflow_node // empty | normalize($overflow; $followers));

def init:
  # To instantly put new tiling windows where they belong, without a moment of 
  # flickering as the script responds to events, we start by putting in place 
  # rules to insert new windows after the window with the `INSERT` mark. To put 
  # it *before* that window, also set the `SWAP` mark.
  "for_window [tiling] move container to mark \(INSERT)",
  "for_window [tiling] swap container with mark \(SWAP)";

def main:
  do(init),
  foreach ipc::subscribe(["workspace", "window", "tick"]) as $e (
    {stack: "left"};
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

main
