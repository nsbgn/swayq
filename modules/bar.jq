import "builtin/ipc" as ipc;
import "builtin/tree" as tree;
import "viz" as viz;
import "workspace" as ws;

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

# Gruvbox colors
def black: "#000000";
def dark: "#282828";
def light: "#d4be98";
def red: "#ea6962";
def orange: "#e78a4e";
def green: "#a9b665";
def blue: "#7daea3";
def purple: "#d3869b";
def aqua: "#89b482";

def colorscheme:
  {
    here_focus:  { color: dark, background: green, border: black },
    here_idle:   { color: light, background: dark, border: green + "90" },
    there_focus: { color: light, background: dark, border: green },
    there_idle:  { color: light, background: dark, border: green + "90" },
  };

def icon:
  "<span> " +
  if .app_id == "org.mozilla.firefox" then
    ""
  elif .app_id == "org.qutebrowser.qutebrowser" then
    ""
  elif .app_id == "Alacritty" or (.app_id | startswith("foot")) then
    ""
  elif .app_id == "org.nicotine_plus.Nicotine" then
    ""
  elif .app_id == "signal" then
    ""
  elif .app_id == "" then
    ""
  else
    ""
  end + " </span>";

def title:
  .name | sub(" — Mozilla Firefox"; "")
;

def workspace($focused_ws):
  . as $ws |
  {
    name: "workspace_separator",
    full_text: " ",
    align: "right",
    separator: false,
    separator_block_width: 0,
    border: "#000000",
    border_right: 3,
    border_left: 3
  },
  (
    tree::focused.id as $focused_win |
    tree::leaves |
    {
      name: "taskbar",
      instance: "\(.id)",
      markup: "pango",
      full_text: "\(icon) \(title | viz::truncate(20))",
      separator_block_width: 0,
    } + colorscheme["\(if $focused_ws then "here" else "there" end)_\(if .id ==
    $focused_win then "focus" else "idle" end)"]
  )
;

# Get process information for PIDs in the tree
def process_info:
  ipc::get_tree |
  [...pid? // empty] |
  unique |
  ["ps", "e", (.[] | "--ppid", tostring), "-o", "ppid=,pid=,tpgid="] |
  exec(.) |
  capture("(?<ppid>[0-9]+)\\s+(?<pid>[0-9]+)\\s+(?<tpgid>[0-9]+)") |
  [exec(["readlink", "-f", "/proc/\(.tpgid)/\("exe", "cwd")"])] as [$exe, $cwd] |
  {pid: .pid | tonumber, $exe, $cwd};

def taskbar:
  tree::focused(.type == "output") |
  .focus[0] as $focus |
  .nodes[] |
  workspace(.id == $focus)
;


def date:
  now | strflocaltime("%Y-%m-%d %H:%M") |
  {full_text: .},
  sleep(15),
  date;

def tasks:
  ipc::subscribe(["workspace", "window", "tick"]) |
  ipc::get_tree |
  [ taskbar ];

if $ARGS.positional[0] == "tgrpid" then
  process_info
else
# Generate strings in the form of the swaybar protocol
{
  "version": 1,
  "click_events": true
},
"[[],",
(
  # Create filters
  ["click_handler", "tasks", "date"] |
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
end
