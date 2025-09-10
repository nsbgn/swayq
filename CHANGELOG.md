# Changelog

### Development

-   (WIP) The `tiling` module was added for facilitating automatic 
    custom dynamic tiling.
-   (WIP) There is a `bar` module for creating a swaybar-compatible 
    status command.
-   (WIP) The `workspace` module was added, which can find the first 
    free workspace and leaf through your workspaces plus the first free 
    one.
-   An `exec/1` internal function is provided that can execute an 
    external process.
-   An `eval/1` internal function is provided that can evaluate filters 
    given as an array of strings. Crucially, these filters can be run in 
    parallel.
-   A `sleep/1` internal function is provided that does nothing
-   The `debug` builtin has been enabled.
-   The `stderr` builtin has been enabled.
-   The `input{,s}` builtins have been enabled for reading from stdin.
-   The `-R` flag toggles between raw and JSON input.
-   There is no longer a default module loaded. Instead, running `swayq` 
    without arguments will produce an overview of available modules. For 
    now, only non-builtin modules are shown.
-   The `-l` flag lists available modules, separated by newlines.
-   Positional arguments are now available in the `$ARGS` variable, in 
    the same format as stock `jq`.
-   **Breaking:** You must now always provide a module. Running `swayq` 
    on its own gives an error message and will eventually list available 
    modules.
-   **Breaking:** The project has been renamed to `swayq`.
-   **Breaking:** The `con::leaves` builtin was fixed.
-   **Breaking:** The `con::focus*` builtins were renamed to 
    `con::focused*`.
-   **Breaking:** Removed `ipc::do`, `extra::among`, `extra::some`, 
    `show::hex`.
-   **Breaking:** Renamed modules `tree`→`con`, `show`→`tree`, and 
    `extra`→`util`.
-   **Breaking:** Moved `truncate` and `pad` from the `tree` module 
    (previously `show`) into `util`.
-   **Breaking:** You can now only set a filter if a module defines no 
    filter of its own; otherwise extra arguments are read as `$ARGS`.

### 0.1.3 (2024-07-21)

-   The `show` module has been added, for text-based visualizations of 
    the tiling tree.
-   ANSI escape sequences may now be used via the newly added `ansi` 
    module.
-   The `show` module has been made the default. As a result, all its 
    functions are available on the CLI without further switches: running 
    `i3jq` without arguments will pretty-print a visualization of the 
    layout tree, and `i3jq watch` will do so continuously.

### 0.1.2 (2024-07-12)

-   Add `lineage/0`, `lineage/1` and `lineage/2` builtins.
-   Add `children/0` builtin.

### 0.1.1 (2024-07-09)

-   **Breaking:** Importing builtin modules must now be done with the 
    `i3jq@` prefix, not the `i3jq/` prefix. Any module with that prefix 
    *must* be a builtin.
-   Builtins can now also be loaded without a prefix, but then modules 
    in the user's configuration take precedence.
-   **Breaking:** Modules in `$ORIGIN/../share/i3jq/` will no longer be 
    found.

## 0.1 (2024-07-06)

First release!
