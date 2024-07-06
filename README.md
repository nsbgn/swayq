# i3jq

*This application is still rough around the edges and interfaces may 
change without warning.*

To programmatically control the window manager [i3] or its sibling 
[Sway][sway], you would usually use a library like [go-i3] or [i3ipc]. 
The library would send and receive some JSON on your behalf, translate 
it to a native structure, and allow you to do your thing.

But why not use a language already tailor-made for JSON transformations: 
[jq]? This allows you to closely follow i3's original [commands][cmd] 
and [IPC spec][ipc]. You get the convenience of a script while staying 
closer to the speed of a compiled program — and the result is often much 
terser than either!

This repository contains the `i3jq` application, which adds internal 
functions corresponding to i3's [IPC spec][ipc] on top of 
[`gojq`][gojq], such as `ipc::subscribe` and `ipc::run_command`. It also 
offers a `tree` module for navigating the layout tree. Finally, in the 
[`contrib/`](./contrib/) directory, you will find filters to achieve 
some useful behaviour.

Much of this would also be achievable with a simple shell script that 
ties together `jq`/`gojq` with `i3msg`/`swaymsg`. However, the `i3jq` 
binary offers some advantages, like readable code and querying for 
information only when necessary. Moreover, you will presumably run these 
commands quite often, so a low footprint is desirable.


## Installation

Make sure you have at least [Go][go] 1.21 installed. Then run:

    go install codeberg.org/nsbg/i3jq@latest


## Usage

You can write a filter to execute a command:

    i3jq 'ipc::get_tree | tree::find(.app_id == "X") | ipc::run_command("[con_id=\(.id)] mark X")'

... or to listen to events:

    i3jq 'ipc::subscribe(["window"]) | .container.name // empty'

You can load a module with the `-m` flag. Modules are searched for in 
the current working directory, `~/.config/i3jq`, `~/.jq`, 
`$ORIGIN/../share/i3jq` and `$ORIGIN/../lib/jq`. To run an `i3jq` script 
within Sway or i3, add a line like this to your configuration:

    exec i3jq -m layout/master-stack

Please view the filters in [`builtin/`](./builtin/) for detailed 
information on the available modules and the functions defined within.


[i3]: https://i3wm.org/
[ipc]: https://i3wm.org/docs/ipc.html
[cmd]: https://i3wm.org/docs/userguide.html#list_of_commands
[sway]: https://swaywm.org/
[swayfx]: https://github.com/WillPower3309/swayfx
[go]: https://go.dev/
[jq]: https://jqlang.github.io/jq/
[gojq]: https://github.com/itchyny/gojq
[i3ipc]: https://github.com/altdesktop/i3ipc-python
[go-i3]: https://github.com/i3/go-i3
