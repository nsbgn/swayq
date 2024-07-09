module {
  name: "base",
  description: "The default module to be loaded."
};

import "i3jq@ipc" as ipc;
import "i3jq@tree" as tree;

ipc::get_tree
