def icon:
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
  end;
