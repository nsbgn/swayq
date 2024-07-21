module {
  name: "ansi",
  description: "ANSI escape codes."
};

# <https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters>

# <https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit>
def color($c; $fg):
  def _colors: {
    "black": [30, 40],
    "red": [31, 41],
    "green": [32, 42],
    "yellow": [33, 43],
    "blue": [34, 44],
    "magenta": [35, 45],
    "cyan": [36, 46],
    "white": [37, 47],
    "lightgray": [37, 47],
    "gray": [90, 100],
    "brightblack": [90, 100],
    "brightred": [91, 101],
    "brightgreen": [92, 102],
    "brightyellow": [93, 103],
    "brightblue": [94, 104],
    "brightmagenta": [95, 105],
    "brightcyan": [96, 106],
    "brightwhite": [97, 107]};

  "\u001b[\(_colors[$c][if $fg then 0 else 1 end])m";

def _wrap($i):
  "\u001b[\($i)m\(.)\u001b[0m";

def bold: _wrap(1);
def dim: _wrap(2);
def italic: _wrap(3);
def underline: _wrap(4);
def invert: _wrap(7);
def clear: "\u001b[2J";
def curpos($i; $j): "\u001b[\($i);\($j)H";
def fg($c): "\(color($c; true))\(.)\u001b[39m";
def bg($c): "\(color($c; false))\(.)\u001b[49m";
