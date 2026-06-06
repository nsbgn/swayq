# swayq-tiling

swayq's tiling module facilitates automatic tiling by implementing a 
customizable *overflow layout*. This encompasses common layouts such as 
`master-stack` and `fibonacci`, which are provided out of the box. 
However, the overflow layout is more general and fits a much broader 
range of tiling approaches.

A key design goal is that it must be seamless. That is:

- No assumptions must be made about the state of the layout tree before 
  the script takes effect.
- We try to avoid flickering as windows move into place.
- The layout can be changed on-the-fly and applied per workspace.


## Schemas

In short, each container follows a *schema* that tells it to accommodate 
at most $n$ child containers. Any one of those children may, in turn, 
follow their own subschema, and so on. As one container fills up, new 
windows will spill over into the next container, according to some 
predetermined priority.

A schema is defined with a JSON structure. For example, the schema for a 
master-stack layout looks like this:

```jq
{ layout: "splith",
  subschemas: [
    { name: "master",
      priority: 1
    },
    { name: "stack",
      capacity: infinite,
      layout: "splitv",
      priority: 2
    }
  ]
}
```

### Keys

The following section describes the keys of a schema.

`subschemas`
: A list of one or more schemas. If this key is absent, then all windows 
assigned to the schema will be direct children of the corresponding 
container. Otherwise, a container will be spawned that is further split 
into one container for each subschema mentioned here.

`layout`
: `"splitv"` | `"splith"` | `"tabbed"` | `"stacked"`. A string 
  corresponding to the i3 layout variants. Defaults to `"splith"`.

`capacity`
: A number indicating how many leaf windows can be accommodated. If 
  subschemas are specified, the capacity is the sum of capacities of 
  those subschemas. Otherwise, this defaults to 1.

`insert-target`
: `"priority"` | `"focus"`. New windows assigned to this schema will be 
  distributed either according to a user-determined, static priority, or 
  the dynamically changing focus list. Defaults to `"priority"`. 

`insert-position`
: `"before"` | `"after"`. Defaults to `"after"`, so that, in the absence 
  of subschemas, new windows assigned to this schema will appear after 
  the last window (if `insert-target` is `"priority"`) or after the 
  focused window (if `insert-target` is `"focus"`). If this value is 
  changed to `"before"`, then they will instead appear before the first 
  window or before the focused window, respectively.

`priority`
: A number indicating the order in which containers will be filled. The 
  lower the number, the sooner the container is filled. If multiple 
  containers have the same priority, new windows will be distributed 
  over them evenly. Defaults to `0`.

<!--
`overflow`
: `"scratchpad"` | `"new"` | `"noop"`

`inherit`
: A boolean.

`rotate`
: `0` | `90` | `180` | `270`.
-->
