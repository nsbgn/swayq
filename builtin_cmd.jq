module {name: "cmd"};

import "i3jq/tree" as tree;
import "i3jq/ipc" as ipc;

# Simple commands

# Swap the input container with the given one
def swap($anchor):
  "[con_id=\(.id)] swap container with con_id \($anchor.id)";

def focus:
  tree::window | "[con_id=\(.id)] focus";

def mark(marks):
  ["[con_id=\(.id)] mark --add \(marks)"] | join("; ");

# Move the input container to the given container
def move_after($anchor):
  "_tmp\($anchor.id)" as $m
  | (if .type == "floating_con" then
      "[con_id=\(.id)] floating disable; "
    else
      ""
    end)
  + "[con_id=\($anchor.id)] mark \($m); "
  + "[con_id=\(.id)] move to mark \($m); "
  + "[con_id=\($anchor.id)] unmark \($m)";

def move_before($anchor):
  move_after($anchor) + "; " + swap($anchor);
