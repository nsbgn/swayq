# swayq

*This application is still rough around the edges and interfaces may 
change without warning.*

`swayq` provides a fast and concise method to script [i3] and [Sway]. It 
takes [`gojq`][gojq] and simply adds internal functions corresponding to 
i3's [IPC spec][ipc], such as `ipc::subscribe` and `ipc::run_command`.

The application also comes [bundled](./modules/) with some useful 
scripts, such as:

- Seamless and configurable dynamic tiling
- Visualising the layout tree
- Breaking out to the first free workspace

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

Much of this would also be achievable with a simple shell script that 
ties together `jq`/`gojq`/`jaq` with `i3msg`/`swaymsg`. However, the 
binary offers some advantages, like the ability communicate with the 
window manager at any point during processing, which makes for more 
efficient and readable scripts. Finally, you will presumably run these 
commands quite often, so a low footprint is desirable.

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

The first argument to the program is the module to load. This defaults 
to [`tree`](./builtin/tree.jq), so that a formatted layout tree is 
generated when no arguments are provided. Modules are searched for in 
the current working directory, `~/.config/swayq`, `~/.config/i3q`, 
`~/.jq` and `$ORIGIN/../lib/jq`. Please view the files in 
[`builtin/`](./builtin/) for detailed information on the builtin modules 
and the functions defined within.

The second optional argument is a jq filter which is executed within the 
context of the module.

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
