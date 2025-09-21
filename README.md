# swayq

*This application is still rough around the edges and interfaces may 
change without warning.*

`swayq` provides a concise and performant way to script [i3] and [Sway]. 
It simply takes [`gojq`][gojq] and adds internal functions corresponding 
to i3's [IPC spec][ipc], such as `subscribe`, as well as functions for 
`exec`uting external commands and `eval`uating filters.

The application comes [bundled](./contrib/) with some useful scripts, 
such as:

- Seamless and endlessly configurable dynamic tiling
- A i3bar-compatible statusbar, as an alternative to [i3blocks] or 
  [i3status-rust]
- An ASCII visualisation of the layout tree
- A module for navigating free workspaces

## Rationale

To programmatically control your window manager, you might use a library 
like [go-i3] or [i3ipc]. The library sends and receives some JSON on 
your behalf, translates it to a native structure, and allows you to do 
your thing.

But why not use a language that is already tailor-made for JSON 
transformations: [jq]? This allows you to closely follow i3's original 
[commands][cmd] and [IPC spec][ipc]. You get the convenience of a script 
while staying closer to the speed of a compiled program — and the result 
is often less verbose than either!

Much of this would also be achievable by cobbling together 
`jq`/`gojq`/`jaq` and `i3msg`/`swaymsg` with shell scripts. However, the 
binary offers some advantages, like the ability to communicate with the 
window manager at any point during processing, which makes for more 
readable scripts with a lower footprint.

## Installation

Make sure you have at least [Go][go] 1.21 installed. Then run:

    go install codeberg.org/nsbg/i3jq@v0.1.3

<!--
    go install codeberg.org/nsbg/swayq@latest
-->


## Usage

You can write a filter to execute a command:

    ipc::get_tree |
    con::find(.app_id == "X") |
    ipc::run_command("[con_id=\(.id)] mark X")'

... or to listen to events:

    ipc::subscribe(["window"]) |
    .container.name // empty

The first argument to the program is the module to load. If none is 
provided, an overview of available modules is shown.

Modules are searched in `~/.config/swayq` and `~/.jq`. Please view the 
files in [`builtin/`](./builtin/) for detailed information on the 
builtin modules and the functions defined within.

If the module is a library, that is, if it only defines functions but no 
filter, then the second argument is a filter which is executed within 
the context of the module. In any case, all remaining arguments are 
available as `$ARGS` within the module.

To run a `swayq` script within Sway or i3, add a line like this to your 
configuration:

    exec swayq tiling master_stack

[i3]: https://i3wm.org/
[ipc]: https://i3wm.org/docs/ipc.html
[cmd]: https://i3wm.org/docs/userguide.html#list_of_commands
[Sway]: https://swaywm.org/
[swayfx]: https://github.com/WillPower3309/swayfx
[go]: https://go.dev/
[jq]: https://jqlang.github.io/jq/
[gojq]: https://github.com/itchyny/gojq
[i3ipc]: https://github.com/altdesktop/i3ipc-python
[go-i3]: https://github.com/i3/go-i3
[i3status-rust]: https://github.com/greshake/i3status-rust
[i3blocks]: https://github.com/vivien/i3blocks
