module {
  name: "tag",
  description: "Attach marks to containers that may be non-unique and that may have additional attributes."
};

import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "util" as util;
import "cmd" as cmd;

# Get all the marks from the layout tree (`ipc::get_tree`) or array of marks
# (`ipc::get_marks`).
def extract_marks:
  if type == "array" then
    .[]
  elif type == "object" then # you may also want `.name == "root"`
    recurse(con::children) | .marks[]
  else
    error("array of strings or layout tree expected")
  end;

# Parse a tag string into its tag, attached attributes, and instance number.
def parse($tag):
  capture("(?<orig>__tag_(?<instance>\\d+)_(?<data>.*)_(?<tag>\(
    if $tag then
      $tag | util::deregex
    else
      ".+"
    end)))") |
  .instance |= tonumber |
  .data |=
    if . == "" then
      null
    else
      @base64d | fromjson
    end;
def parse:
  parse(null);

# Mark a container, but only if not yet marked as such.
def mark($mark):
  if .marks | any(. == $mark) then
    empty
  else
    "[con_id=\(.id)] mark --add \($mark)"
  end;

# Unmark a container. In principle, just sending "unmark" is enough; but if a
# tree or list of existing marks is provided, we can limit sending a command to
# when it's actually necessary.
def unmark($mark; $tree_or_marks):
  if isempty($tree_or_marks | extract_marks | select(. == $mark)) then
    empty
  else
    "unmark \($mark)"
  end;
def unmark($mark):
  unmark($mark; []);

# Tagging is like marking the input container, but allows the usage of the same
# mark for multiple containers and the attachment of additional attributes.
def tag($tag; $data_obj; $tree_or_marks):
  ($data_obj | if . == null then "" else tojson | @base64 end) as $data |
  (.marks | map(parse($tag))) as $cur_tags |
  if $cur_tags | all(.data != $data) then
    ([$tree_or_marks | extract_marks | parse($tag).instance] | max + 1) as $i |
    ($cur_tags[] | "unmark \(.orig)"),
    "[con_id=\(.id)] mark --add __tag_\($i)_\($data)_\($tag)"
  else
    empty
  end
;
def tag($tag; $data):
  tag($tag; $data; ipc::get_marks);
def tag($tag):
  tag($tag; null);

# Remove a tag on a container.
def untag($tag):
  .id as $id |
  .marks[] |
  parse($tag) |
  "[con_id=\($id)] unmark \(.orig)";

$ARGS.positional as $args |
$args[0] as $cmd |
ipc::get_tree |
. as $tree |
if $cmd == "add" then
  con::focused |
  cmd::run(
    tag($args[1]; $args[2] | if . then fromjson end; $tree)
  )
elif $cmd == "rm" then
  con::focused |
  cmd::run(
    untag($args[1])
  )
elif $cmd == "ls" then
  "CON\tTAG\tINST\tDATA", (
    recurse(con::children) |
    .id as $id |
    .marks[] |
    parse |
    if $args[1] then select(.tag == $args[1]) end |
    "\($id)\t\(.tag)\t\(.instance)\t\(.data)"
  )
else
  "unrecognized command"
end

