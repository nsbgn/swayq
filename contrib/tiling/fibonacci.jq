module {
  name: "fibonacci",
  summary: "The fibonacci tiling layout."
};

import "tiling" as tiling;

def schema: {
  layout: "splith",
  subschemas: [
    { name: "head",
      priority: 1
    },
    { name: "tail",
      layout: "splitv",
      priority: 2,
      subschemas: [
        { name: "head",
          priority: 1
        },
        { name: "tail",
          layout: "splith",
          priority: 2,
          subschemas: [
            { name: "tail",
              layout: "splitv",
              priority: 2,
              capacity: infinite
            },
            { name: "head",
              priority: 1
            }
          ]
        }
      ]
    }
  ]
};

tiling::main(schema)
