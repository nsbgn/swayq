module {
  name: "ipc",
  description: "Filters for inter-process communication (IPC) as defined in <https://i3wm.org/docs/ipc.html>."
};

def run_command($payload): _ipc(0; $payload; false);
def get_workspaces: _ipc(1; null; false);
def subscribe($payload): _ipc(2; $payload | tostring; true);
def get_outputs: _ipc(3; null; false);
def get_tree: _ipc(4; null; false);
def get_marks: _ipc(5; null; false);
def get_bar_config($payload): _ipc(6; $payload; false);
def get_bar_config: get_bar_config(null);
def get_version: _ipc(7; null; false);
def get_binding_modes: _ipc(8; null; false);
def get_config: _ipc(9; null; false);
def send_tick($payload): _ipc(10; $payload; false);
def sync($payload): _ipc(11; $payload; false);
def get_binding_state($payload): _ipc(12; $payload; false);
