#! /usr/bin/env zsh

ZLUA_SCRIPT="${0:A:h}/z.lua"

[[ -n "$ZLUA_EXEC" ]] && [[ ! -x "$ZLUA_EXEC" ]] && ZLUA_EXEC=""

# search lua executable
if [[ -z "$ZLUA_EXEC" ]]; then
	if [[ -x "$(command which lua)" ]]; then
		ZLUA_EXEC="$(command which lua)"
	elif [[ -x "$(command which lua5.3)" ]]; then
		ZLUA_EXEC="$(command which lua5.3)"
	elif [[ -x "$(command which lua5.2)" ]]; then
		ZLUA_EXEC="$(command which lua5.2)"
	elif [[ -x "$(command which lua5.1)" ]]; then
		ZLUA_EXEC="$(command which lua5.1)"
	else
		echo "Not find lua in your $PATH, please install it."
		return
	fi
fi

export _ZL_FZF_FLAG="-e"

eval "$($ZLUA_EXEC $ZLUA_SCRIPT --init zsh once enhanced)"


alias zz='z -i'
alias zc='z -c'
alias zf='z -I'
alias zb='z -b'
alias zh='z -I -t .'
alias zzc='zz -c'

