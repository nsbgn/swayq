module {
  name: "bar/tasks"
};

import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "util" as util;
import "workspace" as ws;
import "icon" as icon;
import "color" as color;

def title:
  .name | sub(" — Mozilla Firefox"; "")
;

def marks:
  .marks |
  if . == [] then
    ""
  else
    map(
      select(startswith("_") | not) |
      "<span weight=\"bold\" alpha=\"55%\" style=\"italic\">\(.)</span>"
    ) |
    join("+") |
    " \(.)"
  end;

def workspace($is_focus_ws; $color):
  . as $ws |
  {
    instance: "\(.num)",
    full_text: " <small>\(.num):</small>",
    markup: "pango",
    separator: false,
    separator_block_width: 0,
    color: "#888888"
  },
  (
    con::focused.id as $focus_id |
    [con::leaves] |
    if . == [] then
      if $is_focus_ws then
        { color: $color.focused_workspace_text,
          background: $color.focused_workspace_bg,
          border: $color.focused_workspace_border }
      else
        { color: $color.inactive_workspace_text,
          background: $color.inactive_workspace_bg,
          border: $color.inactive_workspace_border }
      end +
      {
        instance: "\($ws.num)",
        full_text: "\u2731",
        separator: false,
        separator_block_width: 0
      }
    else
      .[0].first = true |
      .[] |
      (.id == $focus_id) as $is_focus_win |
      if $is_focus_win and $is_focus_ws then
        { color: $color.focused_workspace_text,
          background: $color.focused_workspace_bg,
          border: $color.focused_workspace_border }
      elif $is_focus_win then
        { color: $color.active_workspace_text,
          background: $color.active_workspace_bg,
          border: $color.active_workspace_border }
      else
        { color: $color.inactive_workspace_text,
          background: $color.inactive_workspace_bg,
          border: $color.inactive_workspace_border }
      end +
      {
        instance: "\(.id)",
        markup: "pango",
        full_text: " \(icon::icon)  \(title | util::truncate(20))\(marks)",
        separator: false,
        separator_block_width: 3
      }
    end
  )
;

def tasks:
  $ARGS.positional[0] as $bar_id |
  if $bar_id == null then "No bar id given" | error end |
  ipc::get_bar_config($bar_id) as $cfg |
  if $cfg.error then "Could not find bar" | error end |

  # Which output(s) are associated with this bar?
  $cfg.outputs[] as $bar_output |

  # What is the name of that output as it would appear in the tree?
  (ipc::get_outputs[] | 
    if $bar_output == ("\(.make) \(.model) \(.serial)", .name) then
      .name
    else
      empty
    end) as $output_name |

  ipc::subscribe(["workspace", "window", "tick"]) |
  ipc::get_tree |
  [
    .nodes[] |
    select(.name == $output_name) |
    (
      .focus[0] as $focus |
      .nodes[],
      # Also put one empty workspace if none are empty now.
      if .nodes | any(.focus == []) then
        empty
      else
        .nodes |
        first(ws::free) |
        {num: ., nodes: [], floating_nodes: []}
      end |
      workspace(.id == $focus; $cfg.colors)
    ),
    # This shouldn't be necessary, but there's weird padding
    {full_text: "  "}
  ];


def blocks:
  tasks;

def onclick:
  if .button == 1 then
    ipc::run_command("[con_id=\(.instance)] focus")
  elif .button == 3 then
    ipc::run_command("exec dmenu-window")
  else
    empty
  end;
