module {
  name: "index",
  description: "Provide an index of available modules."
};

"Available modules:",
( modules |
  .name |
  (capture("(?<name>.+)\\.jq$").name // .) as $name |
  modulemeta |
  "\u001b[1m\($name)\u001b[0m",
  if .description then
    "\t\(.description)"
  else
    empty
  end
)
