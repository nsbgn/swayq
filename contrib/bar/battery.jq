module {
  name: "bar/battery"
};

def blocks:
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
  blocks;
