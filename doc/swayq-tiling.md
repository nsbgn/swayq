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

: `subschemas`
  A list of one or more schemas. If a schema has subschemas, then the 
  corresponding container will be split up into multiple containers, 
  each of which follows the corresponding schema. If this key is absent, 
  then all windows assigned to the schema will be direct children of the 
  corresponding container.

: `priority`
  A number indicating the order in which containers will be filled.

: `layout`
  A string corresponding to the i3 layout variants `splitv`, `splith`, 
  `tabbed` and `stacked`. Defaults to `splith`.

: `capacity`
  A number indicating how many leaf windows can be accommodated by the 
  schema. If subschemas are specified, the capacity is the sum of 
  capacities of the subschemas. Otherwise, this defaults to 1.

: `reverse`
  A boolean. If the capacity of a schema is greater than 1 but there are 
  no subschemas, then new windows added to this container will appear at 
  the end. If this boolean is set to true, then they will appear at the 
  beginning instead.
