# i3jq

*This application is still rough around the edges.*

To programmatically control the window manager [i3] or its sibling 
compositor [sway], you would usually use a library like [go-i3] or 
[i3ipc]. At the beginning, the library would ask for the layout tree in 
JSON format, translate it to structures native to your language, and 
allow you to do your thing before sending back a command.

But why not use a language tailor-made for JSON transformations 
directly: [jq]? This allows you to closely follow i3's original 
[commands][cmd] and [IPC documentation][ipc]. You get the convenience of 
a script while staying closer to the speed of a compiled program --- and 
the result is often much terser than either.

    # You can listen to events…
    i3jq 'subscribe(["window"]) | .container.name // empty'

    # …or execute commands.
    i3jq 'get_tree | find(.app_id == "X") | run_command("[con_id=\(.id)] mark X")'

This repository contains the `i3jq` application, which adds internal 
functions for IPC on top of [gojq], such as `subscribe` and `get_tree`. 
It also offers example [jq] filters to achieve some useful tasks.

Much of this would also be achievable with a simple shell script that 
ties together `jq`/`gojq` with `i3msg`/`swaymsg`. However, the `i3jq` 
binary offers some advantages, like readable code, keeping track of 
state, and querying for information only when necessary. Moreover, you 
will presumably run these commands quite often, so a low footprint is 
desirable.

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
