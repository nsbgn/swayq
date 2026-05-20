module {
  name: "master-stack",
  summary: "The classic master-stack tiling layout." 
};

import "tiling" as tiling;

def schema: {
  layout: "splith",
  subschemas: [
    { name: "stack",
      capacity: infinite,
      layout: "splitv",
      priority: 2
    },
    { name: "master",
      priority: 1
    }
  ]
};

tiling::main(schema)
