import "builtin/ipc" as ipc;
import "builtin/con" as con;
import "util" as util;
import "workspace" as ws;
import "icon" as icon;
import "color" as color;

def click_handler:
  inputs |
  sub("^,"; "") |
  try (
    fromjson |
    if .name == "taskbar" then
      ipc::run_command("[con_id=\(.instance)] focus")
    else
      ipc::run_command("exec notify-send \([to_entries[].key] | join("."))")
    end
  ) catch empty;

def title:
  .name | sub(" — Mozilla Firefox"; "")
;

def workspace($is_focus_ws):
  {
    name: "workspace",
    instance: "\(.num)",
    full_text: "\(.num | if . > 0 and . <= 10 then [if $is_focus_ws then 10101 else 9311 end + .] | implode else . end)",
    min_width: 30,
    align: "center",
    separator: false,
    separator_block_width: 0,
    color: "#cccccc",
    background: "#000000",
    border_top: 0,
    border_left: 0,
    border_bottom: 0,
    border_right: 0
  },
  (
    if $is_focus_ws then
      "#dddddd"
    else
      "#666666"
    end as $border |
    con::focused.id as $focus_id |
    [con::leaves] |
    if . == [] then
      if $is_focus_ws then
        {fg: "#dddddd", bg: "#555555" }
      else
        {fg: "#888888", bg: "#000000"}
      end as {$fg, $bg} |
      {
        name: "taskbar",
        full_text: "…",
        separator: false,
        separator_block_width: 0,
        color: $fg,
        background: $bg,
        border: $border
      }
    else
      .[0].first = true |
      .[] |
      (.id == $focus_id) as $is_focus_win |
      if $is_focus_win and $is_focus_ws then
        {fg: "#dddddd", bg: "#555555" }
      elif $is_focus_win then
        {fg: "#aaaaaa", bg: "#333333"}
      else
        {fg: "#888888", bg: "#000000"}
      end as {$fg, $bg} |
      {
        name: "taskbar",
        instance: "\(.id)",
        full_text: " \(icon::icon)  \(title | util::truncate(20))",
        separator: false,
        separator_block_width: 0,
        color: $fg,
        background: $bg,
        border: $border,
        border_top: 1,
        border_left: if .first? then 1 else 0 end,
        border_bottom: 1,
        border_right: 1
      }
    end
  )
;

def battery:
  [ exec(["acpi", "-b"]) |
    capture("(?<state>(Not charging|Charging|Discharging)), (?<charge>[0-9]+)%") |
    if .state == "Not charging" then
      "\uf1e6"
    elif .state == "Charging" then
      "\uf0e7"
    else
      .charge | tonumber |
      if   . > 75 then 0
      elif . > 65 then 1
      elif . > 50 then 2
      elif . > 30 then 3
      else 4 end |
      [62016 + .] |
      implode
    end as $icon |
    {full_text: "\($icon) \(.charge)"}
    
  ],
  sleep(100),
  battery;

def volume($sink):
  first(exec(["pactl", "get-sink-volume", $sink])) |
  capture("(?<volume>[0-9]+)%") |
  [{full_text: "\uf028 \(.volume)"}];

def pulseaudio:
  exec(["pactl", "get-default-sink"]) as $sink | # what if it changes
  volume($sink),
  (exec(["pactl", "subscribe"]) |
  select(test("sink")) |
  volume($sink));

def date:
  now | strflocaltime("%Y-%m-%d %H:%M") |
  [{full_text: .}],
  sleep(15),
  date;

def tasks($monitor):
  ipc::subscribe(["workspace", "window", "tick"]) |
  ipc::get_tree |
  [
    if $monitor != null then
      .nodes[] | select(.name == $monitor)
    else
      con::focused(.type == "output")
    end |
    (
      .focus[0] as $focus |
      .nodes[] |
      workspace(.id == $focus)
    ),
    {full_text: " "}
  ];


# Generate strings in the form of the swaybar protocol
{
  "version": 1,
  "click_events": true
},
"[[],",
(
  # Create filters
  ["click_handler", "tasks(\($ARGS.positional[0] | tojson))", "pulseaudio", "battery", "date"] |
  [ . as $args | range(length) | . as $i |
    $args[.] | "\(.) | {channel: \($i), content: .}"] |

  # Evaluate all filters in parallel
  foreach eval(.) as $x (
      [range(length) | []];
      .[$x.channel] = $x.content;
      .[1:] |
      flatten |
      tostring + ","
  )
),
"]"
