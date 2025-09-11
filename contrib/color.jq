def white: "#ffffff";
def black: "#000000";

def bytes2hex:
  "#\(map("0123456789abcdef"[. / 16, . % 16]) | join(""))";

def hex2bytes:
  ltrimstr("#") |
  [ explode.[] | . -
    if . >= 48 and . <= 57 then 48
    elif . >= 65 and . <= 70 then 55
    elif . >= 97 and . <= 102 then 87
    else "not a hexadecimal digit" | error
    end
  ] |
  [ if length % 2 == 1 then .[0] else empty end,
    range(length % 2; length; 2) as $i |
    .[$i] * 16 + .[$i + 1]
  ];

def mix($color; $ratio):
  hex2bytes |
  . as $a |
  ($color | hex2bytes) as $b |
  [ range(length) | $a[.] * (1 - $ratio) + $b[.] * $ratio ] |
  bytes2hex;
