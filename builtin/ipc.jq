module {
  name: "ipc",
  description: "Filters for inter-process communication (IPC) as defined in <https://i3wm.org/docs/ipc.html>."
};

def run_command($payload): _ipc($SOCK; 0; $payload; false);
def get_workspaces: _ipc($SOCK; 1; null; false);
def subscribe($payload): _ipc($SOCK; 2; $payload | tostring; true);
def get_outputs: _ipc($SOCK; 3; null; false);
def get_tree: _ipc($SOCK; 4; null; false);
def get_marks: _ipc($SOCK; 5; null; false);
def get_bar_config($payload): _ipc($SOCK; 6; $payload; false);
def get_bar_config: get_bar_config(null);
def get_version: _ipc($SOCK; 7; null; false);
def get_binding_modes: _ipc($SOCK; 8; null; false);
def get_config: _ipc($SOCK; 9; null; false);
def send_tick($payload): _ipc($SOCK; 10; $payload; false);
def sync($payload): _ipc($SOCK; 11; $payload; false);
def get_binding_state($payload): _ipc($SOCK; 12; $payload; false);
