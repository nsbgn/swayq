#/usr/bin/env bash
# Crude bash completion script. Only does filenames for now.

_modules() {
  swayq completions
}

_swayq_completions() {
  if [ "${#COMP_WORDS[@]}" != "2" ]; then
    return
  fi

  local suggestions=($(compgen -W "$(_modules)" -- "${COMP_WORDS[1]}"))

  COMPREPLY=("${suggestions[@]}")
}

complete -F _swayq_completions i3q
complete -F _swayq_completions swayq
