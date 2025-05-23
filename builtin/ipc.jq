module {
  name: "ipc",
  description: "Filters for inter-process communication (IPC) as defined in <https://i3wm.org/docs/ipc.html>."
};

def run_command($payload): _internal(0; $payload; false);
def get_workspaces: _internal(1; null; false);
def subscribe($payload): _internal(2; $payload | tostring; true);
def get_outputs: _internal(3; null; false);
def get_tree: _internal(4; null; false);
def get_marks: _internal(5; null; false);
def get_bar_config($payload): _internal(6; $payload; false);
def get_bar_config: get_bar_config(null);
def get_version: _internal(7; null; false);
def get_binding_modes: _internal(8; null; false);
def get_config: _internal(9; null; false);
def send_tick($payload): _internal(10; $payload; false);
def sync($payload): _internal(11; $payload; false);
def get_binding_state($payload): _internal(12; $payload; false);
