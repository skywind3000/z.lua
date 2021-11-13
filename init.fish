#! /usr/bin/env fish

if test -z "$XDG_DATA_HOME"
	set -U _ZL_DATA_DIR "$HOME/.local/share/zlua"
else
	set -U _ZL_DATA_DIR "$XDG_DATA_HOME/zlua"
end

set -x _ZL_DATA "$_ZL_DATA_DIR/zlua.txt" 2> /dev/null
set -U _ZL_DATA "$_ZL_DATA_DIR/zlua.txt" 2> /dev/null

if test ! -e "$_ZL_DATA"
	if test ! -e "$_ZL_DATA_DIR"
		mkdir -p -m 700 "$_ZL_DATA_DIR" 2> /dev/null
	end
end

set -x _ZL_DATA "$_ZL_DATA"

set -q XDG_DATA_HOME; or set XDG_DATA_HOME ~/.local/share
if functions -q fisher
	set _zlua_dir $XDG_DATA_HOME/fisher/github.com/skywind3000/z.lua
else
	set _zlua_dir (dirname (status --current-filename))
end

if test -e $_zlua_dir/z.lua 
	if type -q lua
		lua $_zlua_dir/z.lua --init fish enhanced once echo | source
	else if type -q luajit
		luajit $_zlua_dir/z.lua --init fish enhanced once echo | source
	else if type -q lua5.3
		lua5.3 $_zlua_dir/z.lua --init fish enhanced once echo | source
	else if type -q lua5.2
		lua5.2 $_zlua_dir/z.lua --init fish enhanced once echo | source
	else if type -q lua5.1
		lua5.1 $_zlua_dir/z.lua --init fish enhanced once echo | source
	else
		echo "init z.lua failed, not find lua in your system"
	end
	alias zc='z -c'      # restrict matches to subdirs of $PWD
	alias zz='z -i'      # cd with interactive selection
	alias zf='z -I'      # use fzf to select in multiple matches
	alias zb='z -b'      # quickly cd to the parent directory
	alias zbi='z -b -i'  # interactive jump backward
	alias zbf='z -b -I'  # interactive jump backward with fzf
	set -U ZLUA_SCRIPT "$ZLUA_SCRIPT"  2> /dev/null
	set -U ZLUA_LUAEXE "$ZLUA_LUAEXE"  2> /dev/null
end



