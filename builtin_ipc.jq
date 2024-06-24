module {
  name: "ipc",
  description: "Filters for inter-process communication."
};

# IPC as defined in <https://i3wm.org/docs/ipc.html>
def run_command(payload): _i3jq(0; payload; false);
def get_workspaces: _i3jq(1; null; false);
def subscribe(payload): _i3jq(2; payload | tostring; true);
def get_outputs: _i3jq(3; null; false);
def get_tree: _i3jq(4; null; false);
def get_marks: _i3jq(5; null; false);
def get_bar_config(payload): _i3jq(6; payload; false);
def get_version: _i3jq(7; null; false);
def get_binding_modes: _i3jq(8; null; false);
def get_config: _i3jq(9; null; false);
def send_tick(payload): _i3jq(10; payload; false);
def sync(payload): _i3jq(11; payload; false);
def get_binding_state(payload): _i3jq(12; payload; false);

# Shortcuts
def command(p): run_command([p] | flatten | join(";"));
def workspaces: get_workspaces;
def outputs: get_outputs;
def tree: get_tree;
def marks: get_marks;
def get_bar_config: get_bar_config(null);
def bar_config(p): get_bar_config(p);
def bar_config(p): get_bar_config(p);
def version: get_version;
def binding_modes: get_binding_modes;
def config: get_config;
def tick(p): send_tick(p);
def binding_state(p): get_binding_state(p);
