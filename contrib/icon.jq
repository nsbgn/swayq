module {
  name: "icon",
  summary: "Map glyphs from icon fonts to app_ids."
};

def icon:
  .app_id |
  if . == null then
    ""
  elif . == "org.mozilla.firefox" then
    ""
  elif . == "org.qutebrowser.qutebrowser" then
    ""
  elif . == "Alacritty" or startswith("foot") then
    ""
  elif . == "org.nicotine_plus.Nicotine" then
    ""
  elif . == "signal" then
    ""
  elif . == "" then
    ""
  else
    ""
  end;
