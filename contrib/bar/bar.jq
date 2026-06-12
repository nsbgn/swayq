module {
  name: "bar",
  summary: "Scripts for swaybar or i3bar."
};

def handle_click_events:
  inputs |
  sub("^,"; "") |
  try (
    fromjson |
    if has("name") then
      eval("include \"bar/\(.name)\"; onclick")
    end |
    empty
  ) catch empty;

# Generate strings in the form of the swaybar protocol
{
  "version": 1,
  "click_events": true
},
"[[],",
(
  ["tasks", "xkb", "pulseaudio", "battery", "date"] |
  to_entries |
  map("include \"bar/\(.value)\"; blocks | {channel: \(.key), content: map(.name = \"\(.value)\")}") |
  foreach eval(["handle_click_events"] + .) as $x (
      [range(length) | []];
      .[$x.channel] = $x.content;
      flatten |
      tostring + ","
  )
),
"]"
