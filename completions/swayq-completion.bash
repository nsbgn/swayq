#/usr/bin/env bash
# Crude bash completion script. Only does filenames for now.

_files() {
  find ${HOME}/.config/swayq/ ${HOME}/.config/i3q/ -iname '*.jq' -maxdepth 1 -printf '%P\n' 2>/dev/null | sed 's/\.jq$//'
}

_swayq_completions() {
  if [ "${#COMP_WORDS[@]}" != "2" ]; then
    return
  fi

  local suggestions=($(compgen -W "$(_files)" -- "${COMP_WORDS[1]}"))

  COMPREPLY=("${suggestions[@]}")
}

complete -F _swayq_completions i3q
complete -F _swayq_completions swayq
