#! /usr/bin/env zsh

ZLUA_SCRIPT="${0:A:h}/z.lua"

if [[ -n "$ZLUA_EXEC" ]] && ! which "$ZLUA_EXEC" &>/dev/null; then
    echo "$ZLUA_EXEC not found"
    ZLUA_EXEC=""
fi

# search lua executable
if [[ -z "$ZLUA_EXEC" ]]; then
	for lua in lua luajit lua5.4 lua5.3 lua5.2 lua5.1; do
		ZLUA_EXEC="$(command -v "$lua")"
		[[ -n "$ZLUA_EXEC" ]] && break
	done
	if [[ -z "$ZLUA_EXEC" ]]; then
		echo "Not find lua in your $PATH, please install it."
		return
	fi
fi

export _ZL_FZF_FLAG=${_ZL_FZF_FLAG:-"-e"}

eval "$($ZLUA_EXEC $ZLUA_SCRIPT --init zsh once enhanced)"

if [[ -z "$_ZL_NO_ALIASES" ]]; then
  alias zz='z -i'
  alias zc='z -c'
  alias zf='z -I'
  alias zb='z -b'
  alias zbi='z -b -i'
  alias zbf='z -b -I'
  alias zh='z -I -t .'
  alias zzc='zz -c'
fi
