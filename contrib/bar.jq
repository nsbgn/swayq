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
    if .name == "taskbar" and .button == 1 then
      ipc::run_command("[con_id=\(.instance)] focus")
    elif .name == "workspace" and .button == 1 then
      ipc::run_command("workspace \(.instance)")
    elif .name == "pulseaudio" then
      if .button == 1 then
        ipc::run_command("exec pactl set-sink-mute @DEFAULT_SINK@ toggle")
      elif .button == 4 then
        ipc::run_command("exec pactl set-sink-volume @DEFAULT_SINK@ +2%")
      elif .button == 5 then
        ipc::run_command("exec pactl set-sink-volume @DEFAULT_SINK@ -2%")
      end
    else
      ipc::run_command("exec notify-send \(.button)")
    end
  ) catch empty;

def title:
  .name | sub(" — Mozilla Firefox"; "")
;

def workspace($is_focus_ws):
  . as $ws |
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
        name: "workspace",
        instance: "\($ws.num)",
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

def mute:
  first(exec(["pactl", "get-sink-mute", "@DEFAULT_SINK@"])) |
  capture("Mute: (?<mute>(yes|no))") |
  (.mute == "yes");

def volume:
  first(exec(["pactl", "get-sink-volume", "@DEFAULT_SINK@"])) |
  capture("(?<volume>[0-9]+)%") |
  .volume |
  tonumber;

def pulseaudio_once:
  volume |
  if mute then "\uf6a9"
  elif . < 5 then "\uf026"
  elif . < 50 then "\uf027"
  else "\uf028"
  end as $icon |
  [{full_text: "\($icon) \(.)", name: "pulseaudio"}];

def pulseaudio:
  pulseaudio_once,
  ( exec(["pactl", "subscribe"]) |
    select(test("sink")) |
    pulseaudio_once
  );

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
      .nodes[],
      # Also put one empty workspace if none are empty now.
      if .nodes | any(.focus == []) then
        empty
      else
        .nodes |
        first(ws::free) |
        {num: ., nodes: [], floating_nodes: []}
      end |
      workspace(.id == $focus)
    ),
    # This shouldn't be necessary, but there's weird padding
    {full_text: "  "}
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
