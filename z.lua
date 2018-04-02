#! /usr/bin/env lua
--=====================================================================
--
-- z.lua - z.sh implementation for lua
--
-- Created by skywind on 2018/03/19
-- Last Modified: 2018/04/02 19:37
--
--=====================================================================


-----------------------------------------------------------------------
-- Module Header
-----------------------------------------------------------------------
local modname = 'z'
local M = {}
_G[modname] = M
package.loaded[modname] = M  --return modname
setmetatable(M,{__index = _G})

if _ENV ~= nil then
	_ENV[modname] = M
else
	setfenv(1, M)
end


-----------------------------------------------------------------------
-- Environment
-----------------------------------------------------------------------
local windows = package.config:sub(1, 1) ~= '/' and true or false
local in_module = pcall(debug.getlocal, 4, 1) and true or false
os.path = {}
os.argv = arg ~= nil and arg or {}


-----------------------------------------------------------------------
-- Global Variable
-----------------------------------------------------------------------
MAX_AGE = 5000
DATA_FILE = '~/.zlua'
PRINT_TO_STDERR = false
PWD = ''
Z_METHOD = 'frecent'
Z_SUBDIR = false
Z_EXCLUDE = {}


-----------------------------------------------------------------------
-- split string
-----------------------------------------------------------------------
function string:split(sSeparator, nMax, bRegexp)
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)
	local aRecord = {}
	if self:len() > 0 then
		local bPlain = not bRegexp
		nMax = nMax or -1
		local nField, nStart = 1, 1
		local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
		while nFirst and nMax ~= 0 do
			aRecord[nField] = self:sub(nStart, nFirst-1)
			nField = nField+1
			nStart = nLast+1
			nFirst,nLast = self:find(sSeparator, nStart, bPlain)
			nMax = nMax-1
		end
		aRecord[nField] = self:sub(nStart)
	end
	return aRecord
end


-----------------------------------------------------------------------
-- string starts with
-----------------------------------------------------------------------
function string:startswith(text)
	local size = text:len()
	if self:sub(1, size) == text then
		return true
	end
	return false
end


-----------------------------------------------------------------------
-- table size
-----------------------------------------------------------------------
function table.length(T)
	local count = 0
	if T == nil then return 0 end
	for _ in pairs(T) do count = count + 1 end
	return count
end


-----------------------------------------------------------------------
-- print table
-----------------------------------------------------------------------
function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end


-----------------------------------------------------------------------
-- print table
-----------------------------------------------------------------------
function printT(table, level)
	key = ""
	local func = function(table, level)end
	func = function(table, level)
		level = level or 1
		local indent = ""
		for i = 1, level do
			indent = indent.."  "
		end

		if key ~= "" then
			print(indent..key.." ".."=".." ".."{")
		else
			print(indent .. "{")
		end

		key = ""
		for k, v in pairs(table) do
			if type(v) == "table" then
				key = k
				func(v, level + 1)
			else
				local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
				print(content)  
			end
		end
		print(indent .. "}")
	end
	func(table, level)
end


-----------------------------------------------------------------------
-- invoke command and retrive output
-----------------------------------------------------------------------
function os.call(command)
	local fp = io.popen(command)
	if fp == nil then
		return nil
	end
	local line = fp:read('*l')
	fp:close()
	return line
end


-----------------------------------------------------------------------
-- get current path
-----------------------------------------------------------------------
function os.pwd()
	if windows then
		local fp = io.popen('cd')
		if fp == nil then
			return ''
		end
		local line = fp:read('*l')
		fp:close()
		return line
	else
		local fp = io.popen('pwd')
		if fp == nil then
			return ''
		end
		local line = fp:read('*l')
		fp:close()
		return line
	end
end


-----------------------------------------------------------------------
-- which executable
-----------------------------------------------------------------------
function os.path.which(exename)
	local path = os.getenv('PATH')
	if windows then
		paths = ('.;' .. path):split(';')
	else
		paths = path:split(':')
	end
	for _, path in pairs(paths) do
		if not windows then
			local name = path .. '/' .. exename
			if os.path.exists(name) then
				return name
			end
		else
			for _, ext in pairs({'.exe', '.cmd', '.bat'}) do
				local name = path .. '\\' .. exename .. ext
				if path == '.' then
					name = exename .. ext
				end
				if os.path.exists(name) then
					return name
				end
			end
		end
	end
	return nil
end


-----------------------------------------------------------------------
-- get absolute path
-----------------------------------------------------------------------
function os.path.abspath(path)
	if windows then
		local script = 'FOR /F %%i IN ("%s") DO @echo %%~fi'
		local script = string.format(script, path)
		local script = 'cmd.exe /C ' .. script .. ' 2> nul'
		local output = os.call(script)
		return output
	else
		local test = os.path.which('realpath')
		if test ~= nil and test ~= '' then
			return os.call('realpath \'' .. path .. '\'')
		end
		local test = os.path.which('perl')
		if test ~= nil and test ~= '' then
			local s = 'perl -MCwd -e "print Cwd::realpath(\\$ARGV[0])" \'%s\''
			local s = string.format(s, path)
			return os.call(s)
		end
		for _, python in pairs({'python', 'python2', 'python3'}) do
			local s = 'sys.stdout.write(os.path.abspath(sys.argv[1]))'
			local s = '-c "import os, sys;' .. s .. '" \'' .. path .. '\''
			local s = python .. ' ' .. s
			local test = os.path.which(python)
			if test ~= nil and test ~= '' then
				return os.call(s)
			end
		end
	end
end


-----------------------------------------------------------------------
-- dir exists
-----------------------------------------------------------------------
function os.path.isdir(pathname)
	local name = pathname .. '/'
	local ok, err, code = os.rename(name, name)
	if not ok then
		if code == 13 then
			return true
		end
		return false
	end
	return true
end


-----------------------------------------------------------------------
-- file or path exists
-----------------------------------------------------------------------
function os.path.exists(name)
	local ok, err, code = os.rename(name, name)
	if not ok then
		if code == 13 then
			return true
		end
		return false
	end
	return true
end


-----------------------------------------------------------------------
-- is absolute path
-----------------------------------------------------------------------
function os.path.isabs(pathname)
	local h1 = pathname:sub(1, 1)
	if windows then
		local h2 = pathname:sub(2, 2)
		local h3 = pathname:sub(3, 3)
		if h1 == '/' or h1 == '\\' then
			return true
		end
		if h2 == ':' and (h3 == '/' or h3 == '\\') then
			return true
		end
	elseif h1 == '/' then
		return true
	end
	return false
end


-----------------------------------------------------------------------
-- normalize path
-----------------------------------------------------------------------
function os.path.norm(pathname)
	if windows then 
		pathname = pathname:gsub('\\', '/')
	end
	if windows then
		pathname = pathname:gsub('/', '\\')
	end
	return pathname
end


-----------------------------------------------------------------------
-- check subdir
-----------------------------------------------------------------------
function os.path.subdir(basename, subname)
	if windows then
		basename = basename:gsub('\\', '/')
		subname = subname:gsub('\\', '/')
		basename = basename:lower()
		subname = subname:lower()
	end
	local last = basename:sub(-1, -1)
	if last ~= '/' then
		basename = basename .. '/'
	end
	if subname:find(basename, 0, true) == 1 then
		return true
	end
	return false
end


-----------------------------------------------------------------------
-- expand user home
-----------------------------------------------------------------------
function os.path.expand(pathname)
	if not pathname:find('~') then
		return pathname
	end
	local home = ''
	if windows then
		home = os.getenv('USERPROFILE')
	else
		home = os.getenv('HOME')
	end
	if pathname == '~' then
		return home
	end
	local head = pathname:sub(1, 2)
	if windows then
		if head == '~/' or head == '~\\' then
			return home .. '\\' .. pathname:sub(3, -1)
		end
	elseif head == '~/' then
		return home .. '/' .. pathname:sub(3, -1)
	end
	return pathname
end


-----------------------------------------------------------------------
-- get lua executable
-----------------------------------------------------------------------
function os.interpreter()
	if arg == nil then
		return nil
	end
	local lua = arg[-1]	
	if lua == 'lua' then
		return os.path.which('lua')
	end
	return os.path.abspath(lua)
end


-----------------------------------------------------------------------
-- get script name
-----------------------------------------------------------------------
function os.scriptname()
	if arg == nil then
		return nil
	end
	local script = arg[0]
	return os.path.abspath(script)
end


-----------------------------------------------------------------------
-- parse option
-----------------------------------------------------------------------
function os.getopt(argv)
	local args = {}
	local options = {}
	argv = argv ~= nil and argv or os.argv
	if argv == nil then
		return nil, nil
	elseif (#argv) == 0 then
		return options, args
	end
	local count = #argv
	local index = 1
	while index <= count do
		local arg = argv[index]
		local head = arg:sub(1, 1)
		if head ~= '-' then
			break
		end
		index = index + 1
		local part = arg:split('=')
		options[part[1]] = part[2] ~= nil and part[2] or ''
	end
	while index <= count do
		table.insert(args, argv[index])
		index = index + 1
	end
	return options, args
end


-----------------------------------------------------------------------
-- returns true for path is insensitive
-----------------------------------------------------------------------
function path_case_insensitive()
	if windows then 
		return true
	end
	local eos = os.getenv('OS')
	eos = eos ~= nil and eos or ''
	eos = eos:lower()
	if eos:sub(1, 7) == 'windows' then
		return true
	end
	return false
end


-----------------------------------------------------------------------
-- load and split data
-----------------------------------------------------------------------
function data_load(filename)
	local M = {}
	local N = {}
	local insensitive = path_case_insensitive()
	fp = io.open(os.path.expand(filename), 'r')
	if fp == nil then
		return {}
	end
	for line in fp:lines() do
		local part = string.split(line, '|')
		local item = {}
		if part and part[1] and part[2] and part[3] then
			local key = insensitive and part[1]:lower() or part[1]
			item.name = part[1]
			item.rank = tonumber(part[2])
			item.time = tonumber(part[3]) + 0
			item.frecent = item.rank
			if string.len(part[3]) < 12 then
				if item.rank ~= nil and item.time ~= nil then
					if N[key] == nil then
						table.insert(M, item)
						N[key] = 1
					end
				end
			end
		end
	end
	fp:close()
	return M
end


-----------------------------------------------------------------------
-- save data
-----------------------------------------------------------------------
function data_save(filename, M)
	local fp = nil
	local tmpname = nil
	local i
	filename = os.path.expand(filename)
	if windows then
		fp = io.open(filename, 'w')
	else
		tmpname = os.tmpname()
		fp = io.open(tmpname, 'w')
	end
	if fp == nil then
		return false
	end
	for i = 1, #M do
		local item = M[i]
		local text = item.name .. '|' .. item.rank .. '|' .. item.time
		fp:write(text .. '\n')
	end
	fp:close()
	if tmpname ~= nil then
		os.rename(tmpname, filename)
		os.remove(tmpname)
	end
	return true
end


-----------------------------------------------------------------------
-- filter out bad dirname
-----------------------------------------------------------------------
function data_filter(M)
	local N = {}
	local i
	M = M ~= nil and M or {}
	for i = 1, #M do
		local item = M[i]
		if os.path.isdir(item.name) then
			table.insert(N, item)
		end
	end
	return N
end


-----------------------------------------------------------------------
-- insert item
-----------------------------------------------------------------------
function data_insert(M, filename)
	local i = 1
	local sumscore = 0
	for i = 1, #M do 
		local item = M[i]
		sumscore = sumscore + item.rank
	end
	if sumscore >= MAX_AGE then
		local X = {}
		for i = 1, #M do
			local item = M[i]
			item.rank = item.rank * 0.9
			if item.rank >= 1.0 then
				table.insert(X, item)
			end
		end
	end
	local nocase = path_case_insensitive()
	local name = filename
	local key = nocase and string.lower(name) or name
	local find = false
	local current = os.time()
	for i = 1, #M do
		local item = M[i]
		if not nocase then
			if name == item.name then
				item.rank = item.rank + 1
				item.time = current
				find = true
				break
			end
		else
			if key == string.lower(item.name) then
				item.rank = item.rank + 1
				item.time = current
				find = true
				break
			end
		end
	end
	if not find then
		local item = {}
		item.name = name
		item.rank = 1
		item.time = current
		item.frecent = item.rank
		table.insert(M, item)
	end
	return M
end


-----------------------------------------------------------------------
-- change pattern
-----------------------------------------------------------------------
function case_insensitive_pattern(pattern)
	-- find an optional '%' (group 1) followed by any character (group 2)
	local p = pattern:gsub("(%%?)(.)", function(percent, letter)

		if percent ~= "" or not letter:match("%a") then
			-- if the '%' matched, or `letter` is not a letter, return "as is"
			return percent .. letter
		else
			-- else, return a case-insensitive character class of the matched letter
			return string.format("[%s%s]", letter:lower(), letter:upper())
		end
	end)
	return p
end


-----------------------------------------------------------------------
-- pathmatch
-----------------------------------------------------------------------
function path_match(pathname, patterns)
	local pos = 1
	local i = 0
	for i = 1, #patterns do
		local pat = patterns[i]
		start, endup = pathname:find(pat, pos)
		if start == nil or endup == nil then
			return false
		end
		pos = endup + 1
	end
	return true
end


-----------------------------------------------------------------------
-- select matched pathnames
-----------------------------------------------------------------------
function data_select(M, patterns)
	local N = {}
	local i = 1
	local pats = {}
	for i = 1, #patterns do
		local p = patterns[i]
		table.insert(pats, case_insensitive_pattern(p))
	end
	for i = 1, #M do
		local item = M[i]
		if path_match(item.name, pats) then
			table.insert(N, item)
		end
	end
	return N
end


-----------------------------------------------------------------------
-- update frecent
-----------------------------------------------------------------------
function data_update_frecent(M)
	local current = os.time()
	local i
	for i = 1, #M do
		local item = M[i]
		local dx = current - item.time
		if dx < 3600 then 
			item.frecent = item.rank * 4
		elseif dx < 86400 then
			item.frecent = item.rank * 2
		elseif dx < 604800 then
			item.frecent = item.rank * 0.5
		else
			item.frecent = item.rank * 0.25
		end
	end
	return M
end


-----------------------------------------------------------------------
-- add path
-----------------------------------------------------------------------
function z_add(path)
	local paths = {}
	local count = 0
	if type(path) == 'table' then
		paths = path
	elseif type(path) == 'string' then
		paths[1] = path
	end
	if table.length(paths) == 0 then
		return false
	end
	local H = os.getenv('HOME')
	local M = data_load(DATA_FILE)
	M = data_filter(M)
	-- insert paths
	for _, path in pairs(paths) do
		if os.path.isdir(path) and os.path.isabs(path) then
			local skip = false
			local test = path
			path = os.path.norm(path)
			-- check ignore
			if windows then
				if path:len() == 3 and path:sub(2, 2) == ':' then
					local tail = path:sub(3, 3)
					if tail == '/' or tail == '\\' then
						skip = true
					end
				end
				test = os.path.norm(path:lower())
			else
				if H == path then
					skip = true
				end
			end
			-- check exclude
			if not skip then
				for _, exclude in ipairs(Z_EXCLUDE) do
					if test:startswith(exclude) then
						skip = true
						break
					end
				end
			end
			if not skip then
				M = data_insert(M, path)
				count = count + 1
			end
		end
	end
	if count > 0 then
		data_save(DATA_FILE, M)
	end
	return true
end


-----------------------------------------------------------------------
-- match method: frecent, rank, time
-----------------------------------------------------------------------
function z_match(patterns, method, subdir)
	patterns = patterns ~= nil and patterns or {}
	method = method ~= nil and method or 'frecent'
	subdir = subdir ~= nil and subdir or false
	local M = data_load(DATA_FILE)
	M = data_select(M, patterns)
	M = data_filter(M)
	M = data_update_frecent(M)
	if method == 'time' then
		current = os.time()
		for _, item in pairs(M) do
			item.score = item.time - current
		end
	elseif method == 'rank' then
		for _, item in pairs(M) do
			item.score = item.rank
		end
	else
		for _, item in pairs(M) do
			item.score = item.frecent
		end
	end
	table.sort(M, function (a, b) return a.score > b.score end)
	if subdir then
		local pwd = (PWD == nil or PWD == '') and os.getenv('PWD') or PWD
		if pwd ~= '' and pwd ~= nil then 
			local N = {}
			for _, item in pairs(M) do
				if os.path.subdir(pwd, item.name) then
					table.insert(N, item)
				end
			end
			M = N
		end
	end
	return M
end


-----------------------------------------------------------------------
-- pretty print 
-----------------------------------------------------------------------
function z_print(M, number)
	local N = {}
	local maxsize = 10
	local numsize = string.len(tostring(#M))
	for _, item in pairs(M) do
		local record = {}
		record.score = string.format('%.2f', item.score)
		record.name = item.name
		table.insert(N, record)
		if record.score:len() > maxsize then
			maxsize = record.score:len()
		end
	end
	for i = #N, 1, -1 do
		local record = N[i]
		local line = record.score
		while true do
			local tail = line:sub(-1, -1)
			if tail ~= '0' and tail ~= '.' then 
				break 
			end
			line = line:sub(1, -2)
			if tail == '.' then
				break
			end
		end
		local dx = maxsize - line:len()
		if dx > 0 then
			line = line .. string.rep(' ', dx)
		end
		line = line .. '  ' .. record.name
		if number then
			local head = tostring(i)
			if head:len() < numsize then
				head = string.rep(' ', numsize - head:len()) .. head
			end
			line = head .. ':  ' .. line
		end
		if not PRINT_TO_STDERR then
			print(line)
		else
			io.stderr:write(line .. '\n')
		end
	end
end


-----------------------------------------------------------------------
-- calculate jump dir
-----------------------------------------------------------------------
function z_cd(patterns)
	if patterns == nil then
		return nil
	end
	if #patterns == 0 then
		return nil
	end
	local last = patterns[#patterns]
	if last == '~' or last == '~/' then
		return os.path.expand('~')
	elseif windows and last == '~\\' then
		return os.path.expand('~')
	end
	if os.path.isabs(last) and os.path.isdir(last) then
		return os.path.norm(last)
	end
	local M = z_match(patterns, Z_METHOD, Z_SUBDIR)
	if M == nil then
		return nil
	end
	if #M == 0 then
		return nil
	end
	return M[1].name
end




-----------------------------------------------------------------------
-- main entry
-----------------------------------------------------------------------
function main(argv)
	local options, args = os.getopt(argv)
	if options == nil then
		return false
	elseif table.length(args) == 0 and table.length(options) == 0 then
		print(os.argv[0] .. ': missing arguments')
		help = os.argv[-1] .. ' ' .. os.argv[0] .. ' --help'
		print('Try \'' .. help .. '\' for more information')
		return false
	end
	if false then
		print("options: ")
		printT(options)
		print("args: ")
		printT(args)
	end
	if options['-c'] ~= nil then
		Z_SUBDIR = true
	end
	if options['-r'] ~= nil then
		Z_METHOD = 'rank'
	elseif options['-t'] ~= nil then
		Z_METHOD = 'time'
	end
	if options['--cd'] ~= nil then
		local path = ''
		if #args == 0 then
			path = os.path.expand('~')
		else
			path = z_cd(args)
		end
		if path ~= nil then
			io.write(path)
		end
	elseif options['--add'] ~= nil then
		-- print('data: ' .. DATA_FILE)
		z_add(args)
	elseif options['--init'] ~= nil then
		local opts = {}
		for _, key in ipairs(args) do
			opts[key] = 1
		end
		z_shell_init(opts)
	elseif options['-l'] ~= nil then
		local M = z_match(args ~= nil and args or {}, Z_METHOD, Z_SUBDIR)
		z_print(M)
	elseif options['--complete'] ~= nil then
		local M = z_match(args ~= nil and args or {}, Z_METHOD, Z_SUBDIR)
		for _, item in pairs(M) do
			print(item.name)
		end
	end
	return true
end


-----------------------------------------------------------------------
-- initialize from environment variable
-----------------------------------------------------------------------
function z_init()
	local _zl_data = os.getenv('_ZL_DATA')
	local _zl_maxage = os.getenv('_ZL_MAXAGE')
	local _zl_exclude = os.getenv('_ZL_EXCLUDE')
	if _zl_data ~= nil and _zl_data ~= "" then
		if windows then
			DATA_FILE = _zl_data
		else
			-- avoid windows environments affect cygwin & msys
			if _zl_data:sub(2, 2) ~= ':' then
				local t = _zl_data:sub(3, 3)
				if t ~= '/' and t ~= "\\" then
					DATA_FILE = _zl_data
				end
			end
		end
	end
	if _zl_maxage ~= nil and _zl_maxage ~= "" then
		_zl_maxage = tonumber(_zl_maxage)
		if _zl_maxage ~= nil and _zl_maxage > 0 then
			MAX_AGE = _zl_maxage
		end
	end
	if _zl_exclude ~= nil and _zl_exclude ~= "" then
		local part = _zl_exclude:split(windows and ';' or ':')
		local insensitive = path_case_insensitive()
		for _, name in ipairs(part) do
			if insensitive then
				name = name:lower()
			end
			if windows then
				name = os.path.norm(name)
			end
			Z_EXCLUDE[name] = 1
		end
	end
end


-----------------------------------------------------------------------
-- initialize clink hooks
-----------------------------------------------------------------------
function z_clink_init()
	function z_add_to_database()
		z_add(clink.get_cwd())
	end
	clink.prompt.register_filter(z_add_to_database, 99)
	function z_match_completion(word)
		local M = z_match({word}, Z_METHOD, Z_SUBDIR)
		for _, item in pairs(M) do
			clink.add_match(item.name)
		end
		return {}
	end
	local z_parser = clink.arg.new_parser()
	z_parser:set_arguments({ z_match_completion })
	clink.arg.register_parser("z", z_parser)
end


-----------------------------------------------------------------------
-- shell scripts
-----------------------------------------------------------------------
local script_zlua = [[
function _zlua() {
	local arg_list=""
	local arg_type=""
	local arg_subdir=""
	local arg_loop="1"
	local arg_echo=""
	local arg_help=""
	if [ "$1" = "--add" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --add "$@"
		return
	fi
	if [ "$1" = "--complete" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --complete "$@"
		return 
	fi
	while [ "$1" ]; do
		case "$1" in 
			-l) local arg_list="-l" ;;
			-t) local arg_type="-t" ;;
			-r) local arg_type="-r" ;;
			-c) local arg_subdir="-c" ;;
			-e) local arg_echo="1" ;;
			-h) local arg_help="-h" ;;
			*) break ;;
		esac
		shift
	done
	if [ -n "$arg_help" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -h
	elif [ -n "$arg_list" ] || [ "$#" -eq 0 ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -l "$@"
	else
		local dest=$("$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --cd $arg_type $arg_subdir "$@")
		if [ "$dest" ] && [ -d "$dest" ]; then
			[ -n "$arg_echo" ] && echo "$dest"
			if [ -z "$_ZL_NOBUILTIN" ]; then
				builtin cd "$dest"
			else
				cd "$dest"
			fi
		fi
	fi
}
# alias ${_ZL_CMD:-z}='_zlua 2>&1'
alias ${_ZL_CMD:-z}='_zlua'
]]

local script_init_bash = [[
case "$PROMPT_COMMAND" in 
	*_zlua?--add*) ;;
	*) PROMPT_COMMAND="_zlua --add \"\$(command pwd 2>/dev/null)\";$PROMPT_COMMAND" ;;
esac
]]

local script_init_bash_fast = [[
case "$PROMPT_COMMAND" in 
	*_zlua?--add*) ;;
	*) PROMPT_COMMAND="_zlua --add \"\$PWD\";$PROMPT_COMMAND" ;;
esac
]]

local script_init_zsh = [[
_zlua_precmd() {
	(_zlua --add "${PWD:a}" &)
}
[ -n "${precmd_functions[(r)_zlua_precmd]}" ] || {
	precmd_functions[$(($#precmd_functions+1))]=_zlua_precmd
}
]]

local script_complete_bash = [[
complete -o filenames -C '_zlua --complete "$COMP_LINE"' ${_ZL_CMD:-z}
]]

local script_complete_zsh = [[
_zlua_zsh_tab_completion() {
	# tab completion
	local compl
	read -l compl
	reply=(${(f)"$(_zlua --complete "$compl")"})
}
compctl -U -K _zlua_zsh_tab_completion _zlua
]]


-----------------------------------------------------------------------
-- initialize bash/zsh
----------------------------------------------------------------------
function z_shell_init(opts)
	print('ZLUA_SCRIPT="' .. os.scriptname() .. '"')
	print('ZLUA_LUAEXE="' .. os.interpreter() .. '"')
	print('')
	print(script_zlua)

	if opts.bash ~= nil then
		if os.getenv("_Z_NO_PROMPT_COMMAND") == nil then
			if opts.fast == nil then
				print(script_init_bash)
			else
				print(script_init_bash_fast)
			end
		end
		print(script_complete_bash)
	elseif opts.zsh ~= nil then
		if os.getenv("_Z_NO_PROMPT_COMMAND") == nil then
			print(script_init_zsh)
		end
		print(script_complete_zsh)
	end
end


-----------------------------------------------------------------------
-- testing case
-----------------------------------------------------------------------
if not pcall(debug.getlocal, 4, 1) then
	-- main script
	z_init()
	if windows and type(clink) == 'table' and clink.prompt ~= nil then
		z_clink_init()
	else
		main()
	end
end


