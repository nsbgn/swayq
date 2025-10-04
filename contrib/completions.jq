module {
  name: "completions"
};

modules |
capture("(?<name>.+)\\.jq$").name // .
