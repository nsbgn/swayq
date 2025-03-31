# i3jq

*This application is still rough around the edges and interfaces may 
change without warning.*

To programmatically control the window manager [i3] or its younger 
sibling [Sway][sway], you might use a library like [go-i3] or [i3ipc]. 
The library sends and receives some JSON on your behalf, translates it 
to a native structure, and allows you to do your thing.

But why not use a language that is already tailor-made for JSON 
transformations: [jq]? This allows you to closely follow i3's original 
[commands][cmd] and [IPC spec][ipc]. You get the convenience of a script 
while staying closer to the speed of a compiled program — and the result 
is often much terser than either!

This repository contains the `i3jq` application, which adds internal 
functions corresponding to i3's [IPC spec][ipc] on top of 
[`gojq`][gojq], such as `ipc::subscribe` and `ipc::run_command`. It also 
offers a `tree` module for navigating the layout tree. Finally, in the 
[`contrib/`](./contrib/) directory, you will find filters to achieve 
some useful behaviour.

Much of this would also be achievable with a simple shell script that 
ties together `jq`/`gojq` with `i3msg`/`swaymsg`. However, the `i3jq` 
binary offers some advantages, like the ability communicate with i3 at 
any point during processing, which makes for more efficient and readable 
scripts. Moreover, you will presumably run these commands quite often, 
so a low footprint is desirable.


## Installation

Make sure you have at least [Go][go] 1.21 installed. Then run:

    go install codeberg.org/nsbg/i3jq@latest


## Usage

You can write a filter to execute a command:

    ipc::get_tree |
    tree::find(.app_id == "X") |
    ipc::run_command("[con_id=\(.id)] mark X")'

... or to listen to events:

    ipc::subscribe(["window"]) |
    .container.name // empty

The first argument to the program is the module to load. This defaults 
to [`show`](./builtin/show.jq), so that a formatted layout tree is 
generated when no arguments are provided. Modules are searched for in 
the current working directory, `~/.config/i3jq`, `~/.jq` and 
`$ORIGIN/../lib/jq`. Please view the files in [`builtin/`](./builtin/) 
for detailed information on the available modules and the functions 
defined within.

The second optional argument is a jq filter which is executed within the 
context of the module.

To run an `i3jq` script within Sway or i3, add a line like this to your 
configuration:

    exec i3jq master-stack

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
