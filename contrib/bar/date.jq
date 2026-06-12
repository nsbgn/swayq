module {
  name: "bar/date"
};

def blocks:
  now |
  strflocaltime("%Y-%m-%d %H:%M") |
  [{full_text: .}],
  sleep(15),
  blocks;


