module {
  name: "ipc",
  description: "Filters for inter-process communication (IPC) as defined in <https://i3wm.org/docs/ipc.html>."
};

def socket: $ENV["SWAYSOCK"] // $ENV["I3SOCK"];

def run_command($payload): _ipc(socket; 0; $payload; false);
def get_workspaces: _ipc(socket; 1; null; false);
def subscribe($payload): _ipc(socket; 2; $payload | tostring; true);
def get_outputs: _ipc(socket; 3; null; false);
def get_tree: _ipc(socket; 4; null; false);
def get_marks: _ipc(socket; 5; null; false);
def get_bar_config($payload): _ipc(socket; 6; $payload; false);
def get_bar_config: get_bar_config(null);
def get_version: _ipc(socket; 7; null; false);
def get_binding_modes: _ipc(socket; 8; null; false);
def get_config: _ipc(socket; 9; null; false);
def send_tick($payload): _ipc(socket; 10; $payload; false);
def sync($payload): _ipc(socket; 11; $payload; false);
def get_binding_state($payload): _ipc(socket; 12; $payload; false);
