#! /usr/bin/env lua
--=====================================================================
--
-- z.lua - z.sh implementation in lua, by skywind 2018, 2019
-- Licensed under MIT license.
--
-- Version 1.3.0, Last Modified: 2019/02/04 00:06
--
-- * 10x times faster than fasd and autojump
-- * 3x times faster than rupa/z
-- * available for posix shells: bash, zsh, sh, ash, dash, busybox
-- * supports windows
-- * compatible with lua 5.1, 5.2 and 5.3+
--
-- USE:
--     * z foo      # cd to most frecent dir matching foo
--     * z foo bar  # cd to most frecent dir matching foo and bar
--     * z -r foo   # cd to highest ranked dir matching foo
--     * z -t foo   # cd to most recently accessed dir matching foo
--     * z -l foo   # list matches instead of cd
--     * z -c foo   # restrict matches to subdirs of $PWD
--     * z -e foo   # echo the best match, don't cd
--     * z -x path  # remove path from history
--     * z -i foo   # cd with interactive selection
--
-- Bash Install:
--     * put something like this in your .bashrc:
--         eval "$(lua /path/to/z.lua --init bash)"
--
-- Bash Fast Mode:
--     * put something like this in your .bashrc:
--         eval "$(lua /path/to/z.lua --init bash fast)"
--
-- Zsh Install:
--     * put something like this in your .zshrc:
--         eval "$(lua /path/to/z.lua --init zsh)"
--
-- Posix Shell Install:
--     * put something like this in your .profile:
--         eval "$(lua /path/to/z.lua --init posix)"
--
-- Windows Install (with Clink):
--     * copy z.lua and z.cmd to clink's home directory
--     * Add clink's home to %PATH% (z.cmd can be called anywhere)
--     * Ensure that "lua" can be called in %PATH%
--
-- Windows Cmder Install:
--     * copy z.lua and z.cmd to cmder/vendor
--     * Add cmder/vendor to %PATH%
--     * Ensure that "lua" can be called in %PATH%
--
-- Configure (optional):
--   set $_ZL_CMD in .bashrc/.zshrc to change the command (default z).
--   set $_ZL_DATA in .bashrc/.zshrc to change the datafile (default ~/.zlua).
--   set $_ZL_NO_PROMPT_COMMAND if you're handling PROMPT_COMMAND yourself.
--   set $_ZL_EXCLUDE_DIRS to an array of directories to exclude.
--   set $_ZL_ADD_ONCE to 1 to update database only if $PWD changed.
--   set $_ZL_CD to specify your own cd command
--   set $_ZL_ECHO to 1 to display new directory name after cd.
--   set $_ZL_MAXAGE to define a aging threshold (default is 5000).
--   set $_ZL_MATCH_MODE to 1 to enable enhanced matching mode.
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
local utils = {}
os.path = {}
os.argv = arg ~= nil and arg or {}
os.path.sep = windows and '\\' or '/'


-----------------------------------------------------------------------
-- Global Variable
-----------------------------------------------------------------------
MAX_AGE = 5000
DATA_FILE = '~/.zlua'
PRINT_MODE = '<stdout>'
PWD = ''
Z_METHOD = 'frecent'
Z_SUBDIR = false
Z_INTERACTIVE = 0
Z_EXCLUDE = {}
Z_CMD = 'z'
Z_MATCHMODE = 0
Z_MATCHNAME = false
Z_SKIPPWD = false

os.LOG_NAME = os.getenv('_ZL_LOG_NAME')



-----------------------------------------------------------------------
-- string lib
-----------------------------------------------------------------------
function string:split(sSeparator, nMax, bRegexp)
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)
	local aRecord = {}
	if self:len() > 0 then
		local bPlain = not bRegexp
		nMax = nMax or -1
		local nField, nStart = 1, 1
		local nFirst, nLast = self:find(sSeparator, nStart, bPlain)
		while nFirst and nMax ~= 0 do
			aRecord[nField] = self:sub(nStart, nFirst - 1)
			nField = nField + 1
			nStart = nLast + 1
			nFirst, nLast = self:find(sSeparator, nStart, bPlain)
			nMax = nMax - 1
		end
		aRecord[nField] = self:sub(nStart)
	else
		aRecord[1] = ''
	end
	return aRecord
end

function string:startswith(text)
	local size = text:len()
	if self:sub(1, size) == text then
		return true
	end
	return false
end

function string:lstrip()
	if self == nil then return nil end
	local s = self:gsub('^%s+', '')
	return s
end

function string:rstrip()
	if self == nil then return nil end
	local s = self:gsub('%s+$', '')
	return s
end

function string:strip()
	return self:lstrip():rstrip()
end

function string:rfind(key)
	if keyword == '' then
		return self:len(), 0
	end
	local length = self:len()
	local start, ends = self:reverse():find(key:reverse())
	if start == nil then
		return nil
	end
	return (length - ends + 1), (length - start + 1)
end

function string:join(parts)
	if parts == nil or #parts == 0 then
		return ''
	end
	local size = #parts
	local text = ''
	local index = 1
	while index <= size do
		if index == 1 then
			text = text .. parts[index]
		else
			text = text .. self .. parts[index]
		end
		index = index + 1
	end
	return text
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
-- write log
-----------------------------------------------------------------------
function os.log(text)
	if not os.LOG_NAME then
		return
	end
	local fp = io.open(os.LOG_NAME, 'a')
	if not fp then
		return
	end
	local date = "[" .. os.date('%Y-%m-%d %H:%M:%S') .. "] "
	fp:write(date .. text .. "\n")
	fp:close()
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
-- absolute path (simulated)
-----------------------------------------------------------------------
function os.path.absolute(path)
	local pwd = os.pwd()
	return os.path.normpath(os.path.join(pwd, path))
end


-----------------------------------------------------------------------
-- absolute path (system call, can fall back to os.path.absolute)
-----------------------------------------------------------------------
function os.path.abspath(path)
	if path == '' then path = '.' end
	if windows then
		local script = 'FOR /f "delims=" %%i IN ("%s") DO @echo %%~fi'
		local script = string.format(script, path)
		local script = 'cmd.exe /C ' .. script .. ' 2> nul'
		local output = os.call(script)
		local test = output:gsub('%s$', '')
		if test ~= nil and test ~= '' then
			return test
		end
	else
		local test = os.path.which('realpath')
		if test ~= nil and test ~= '' then
			test = os.call('realpath -s \'' .. path .. '\' 2> /dev/null')
			if test ~= nil and test ~= '' then
				return test
			end
		end
		if os.path.isdir(path) then
			if os.path.exists('/bin/sh') and os.path.exists('/bin/pwd') then
				local cmd = "/bin/sh -c 'cd \"" ..path .."\"; /bin/pwd'"
				test = os.call(cmd)
				if test ~= nil and test ~= '' then
					return test
				end
			end
		end
		local test = os.path.which('perl')
		if test ~= nil and test ~= '' then
			local s = 'perl -MCwd -e "print Cwd::realpath(\\$ARGV[0])" \'%s\''
			local s = string.format(s, path)
			test = os.call(s)
			if test ~= nil and test ~= '' then
				return test
			end
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
	return os.path.absolute(path)
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
function os.path.isabs(path)
	if path == nil or path == '' then
		return false
	elseif path:sub(1, 1) == '/' then
		return true
	end
	if windows then
		local head = path:sub(1, 1)
		if head == '\\' then
			return true
		elseif path:match('^%a:[/\\]') ~= nil then
			return true
		end
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
-- normalize . and ..
-----------------------------------------------------------------------
function os.path.normpath(path)
	if os.path.sep ~= '/' then
		path = path:gsub('\\', '/')
	end
	path = path:gsub('/+', '/')
	local srcpath = path
	local basedir = ''
	local isabs = false
	if windows and path:sub(2, 2) == ':' then
		basedir = path:sub(1, 2)
		path = path:sub(3, -1)
	end
	if path:sub(1, 1) == '/' then
		basedir = basedir .. '/'
		isabs = true
		path = path:sub(2, -1)
	end
	local parts = path:split('/')
	local output = {}
	for _, path in ipairs(parts) do
		if path == '.' or path == '' then
		elseif path == '..' then
			local size = #output
			if size == 0 then
				if not isabs then
					table.insert(output, '..')
				end
			elseif output[size] == '..' then
				table.insert(output, '..')
			else
				table.remove(output, size)
			end
		else
			table.insert(output, path)
		end
	end
	path = basedir .. string.join('/', output)
	if windows then path = path:gsub('/', '\\') end
	return path == '' and '.' or path
end


-----------------------------------------------------------------------
-- join two path
-----------------------------------------------------------------------
function os.path.join(path1, path2)
	if path1 == nil or path1 == '' then
		if path2 == nil or path2 == '' then
			return ''
		else
			return path2
		end
	elseif path2 == nil or path2 == '' then
		local head = path1:sub(-1, -1)
		if head == '/' or (windows and head == '\\') then
			return path1
		end
		return path1 .. os.path.sep
	elseif os.path.isabs(path2) then
		if windows then
			local head = path2:sub(1, 1)
			if head == '/' or head == '\\' then
				if path1:match('^%a:') then
					return path1:sub(1, 2) .. path2
				end
			end
		end
		return path2
	elseif windows then
		local d1 = path1:match('^%a:') and path1:sub(1, 2) or ''
		local d2 = path2:match('^%a:') and path2:sub(1, 2) or ''
		if d1 ~= '' then
			if d2 ~= '' then
				if d1:lower() == d2:lower() then
					return d2 .. os.path.join(path1:sub(3), path2:sub(3))
				else
					return path2
				end
			end
		elseif d2 ~= '' then
			return path2
		end
	end
	local postsep = true
	local len1 = path1:len()
	local len2 = path2:len()
	if path1:sub(-1, -1) == '/' then
		postsep = false
	elseif windows then
		if path1:sub(-1, -1) == '\\' then
			postsep = false
		elseif len1 == 2 and path1:sub(2, 2) == ':' then
			postsep = false
		end
	end
	if postsep then
		return path1 .. os.path.sep .. path2
	else
		return path1 .. path2
	end
end


-----------------------------------------------------------------------
-- split
-----------------------------------------------------------------------
function os.path.split(path)
	if path == '' then
		return '', ''
	end
	local pos = path:rfind('/')
	if os.path.sep == '\\' then
		local p2 = path:rfind('\\')
		if pos == nil and p2 ~= nil then
			pos = p2
		elseif p1 ~= nil and p2 ~= nil then
			pos = (pos < p2) and pos or p2
		end
		if path:match('^%a:[/\\]') and pos == nil then
			return path:sub(1, 2), path:sub(3)
		end
	end
	if pos == nil then
		if windows then
			local drive = path:match('^%a:') and path:sub(1, 2) or ''
			if drive ~= '' then
				return path:sub(1, 2), path:sub(3)
			end
		end
		return '', path
	elseif pos == 1 then
		return path:sub(1, 1), path:sub(2)
	elseif windows then
		local drive = path:match('^%a:') and path:sub(1, 2) or ''
		if pos == 3 then
			return path:sub(1, 3), path:sub(4)
		end
	end
	local head = path:sub(1, pos)
	local tail = path:sub(pos + 1)
	if not windows then
		local test = string.rep('/', head:len())
		if head ~= test then
			head = head:gsub('/+$', '')
		end
	else
		local t1 = string.rep('/', head:len())
		local t2 = string.rep('\\', head:len())
		if head ~= t1 and head ~= t2 then
			head = head:gsub('[/\\]+$', '')
		end
	end
	return head, tail
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
-- check single name element
-----------------------------------------------------------------------
function os.path.single(path)
	if string.match(path, '/') then
		return false
	end
	if windows then
		if string.match(path, '\\') then
			return false
		end
	end
	return true
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
-- search executable
-----------------------------------------------------------------------
function os.path.search(name)
end


-----------------------------------------------------------------------
-- get lua executable
-----------------------------------------------------------------------
function os.interpreter()
	if os.argv == nil then
		io.stderr:write("cannot get arguments (arg), recompiled your lua\n")
		return nil
	end
	local lua = os.argv[-1]
	if lua == nil then
		io.stderr:write("cannot get executable name, recompiled your lua\n")
	end
	if os.path.single(lua) then
		local path = os.path.which(lua)
		if not os.path.isabs(path) then
			return os.path.abspath(path)
		end
		return path
	end
	return os.path.abspath(lua)
end


-----------------------------------------------------------------------
-- get script name
-----------------------------------------------------------------------
function os.scriptname()
	if os.argv == nil then
		io.stderr:write("cannot get arguments (arg), recompiled your lua\n")
		return nil
	end
	local script = os.argv[0]
	if script == nil then
		io.stderr:write("cannot get script name, recompiled your lua\n")
	end
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
		if arg ~= '' then
			if head ~= '-' then
				break
			end
			local part = arg:split('=')
			options[part[1]] = part[2] ~= nil and part[2] or ''
		end
		index = index + 1
	end
	while index <= count do
		table.insert(args, argv[index])
		index = index + 1
	end
	return options, args
end


-----------------------------------------------------------------------
-- generate random seed
-----------------------------------------------------------------------
function math.random_init()
	-- random seed from os.time()
	local seed = tostring(os.time() * 1000)
	seed = seed .. tostring(math.random(99999999))
	if os.argv ~= nil then
		for _, key in ipairs(os.argv) do
			seed = seed .. '/' .. key
		end
	end
	local ppid = os.getenv('PPID')
	seed = (ppid ~= nil) and (seed .. '/' .. ppid) or seed
	-- random seed from socket.gettime()
	local status, socket = pcall(require, 'socket')
	if status then
		seed = seed .. tostring(socket.gettime())
	end
	-- random seed from _ZL_RANDOM
	local rnd = os.getenv('_ZL_RANDOM')
	if rnd ~= nil then
		seed = seed .. rnd
	end
	if not windows then
		local fp = io.open('/dev/random', 'rb')
		if fp ~= nil then
			seed = seed .. fp:read(10)
			fp:close()
		end
	else
		if math.random_inited == nil then
			math.random_inited = 1
			local name = os.tmpname()
			os.remove(name)
			seed = seed .. name
		end
	end
	seed = seed .. tostring(os.clock() * 10000000)
	local number = 0
	for i = 1, seed:len() do
		local k = string.byte(seed:sub(i, i))
		number = ((number * 127) % 0x7fffffff) + k
	end
	math.randomseed(number)
end


-----------------------------------------------------------------------
-- math random string
-----------------------------------------------------------------------
function math.random_string(N)
	local text = ''
	for i = 1, N do
		local k = math.random(0, 26 * 2 + 10 - 1)
		if k < 26 then
			text = text .. string.char(0x41 + k)
		elseif k < 26 * 2 then
			text = text .. string.char(0x61 + k - 26)
		elseif k < 26 * 2 + 10 then
			text = text .. string.char(0x30 + k - 26 * 2)
		else
		end
	end
	return text
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
		math.random_init()
		tmpname = filename .. '.' .. tostring(os.time())
		tmpname = tmpname .. math.random_string(8)
		local rnd = os.getenv('_ZL_RANDOM')
		tmpname = tmpname .. '' .. (rnd and rnd or '')
		-- print('tmpname: '..tmpname)
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
		M = X
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
-- change database
-----------------------------------------------------------------------
function data_file_set(name)
	DATA_FILE = name
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
function path_match(pathname, patterns, matchlast)
	local pos = 1
	local i = 0
	local matchlast = matchlast ~= nil and matchlast or false
	for i = 1, #patterns do
		local pat = patterns[i]
		start, endup = pathname:find(pat, pos)
		if start == nil or endup == nil then
			return false
		end
		pos = endup + 1
	end
	if matchlast and #patterns > 0 then
		local last = ''
		local index = #patterns
		local pat = patterns[index]
		if not windows then
			last = string.match(pathname, ".*(/.*)")
		else
			last = string.match(pathname, ".*([/\\].*)")
		end
		if last then
			start, endup = last:find(pat, 1)
			if start == nil or endup == nil then
				return false
			end
		end
	end
	return true
end


-----------------------------------------------------------------------
-- select matched pathnames
-----------------------------------------------------------------------
function data_select(M, patterns, matchlast)
	local N = {}
	local i = 1
	local pats = {}
	for i = 1, #patterns do
		local p = patterns[i]
		table.insert(pats, case_insensitive_pattern(p))
	end
	for i = 1, #M do
		local item = M[i]
		if path_match(item.name, pats, matchlast) then
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
-- remove path
-----------------------------------------------------------------------
function z_remove(path)
	local paths = {}
	local count = 0
	local remove = {}
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
	local X = {}
	M = data_filter(M)
	for _, path in pairs(paths) do
		path = os.path.abspath(path)
		remove[path] = 1
	end
	for i = 1, #M do
		local item = M[i]
		if not remove[item.name] then
			table.insert(X, item)
			-- print('include:'..item.name)
		end
	end
	data_save(DATA_FILE, X)
end


-----------------------------------------------------------------------
-- match method: frecent, rank, time
-----------------------------------------------------------------------
function z_match(patterns, method, subdir)
	patterns = patterns ~= nil and patterns or {}
	method = method ~= nil and method or 'frecent'
	subdir = subdir ~= nil and subdir or false
	local M = data_load(DATA_FILE)
	M = data_select(M, patterns, false)
	if Z_MATCHNAME then
		local N = data_select(M, patterns, true)
		if #N > 0 then
			M = N
		end
	end
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
	local pwd = (PWD == nil or PWD == '') and os.getenv('PWD') or PWD
	if pwd == nil or pwd == '' then
		pwd = os.pwd()
	end
	if pwd ~= '' and pwd ~= nil then
		if subdir then
			local N = {}
			for _, item in pairs(M) do
				if os.path.subdir(pwd, item.name) then
					table.insert(N, item)
				end
			end
			M = N
		end
		if Z_SKIPPWD then
			local N = {}
			local key = windows and string.lower(pwd) or pwd
			for _, item in pairs(M) do
				local match = false
				local name = windows and string.lower(item.name) or item.name
				if name ~= key then
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
function z_print(M, weight, number)
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
	local fp = io.stdout
	if PRINT_MODE == '<stdout>' then
		fp = io.stdout
	elseif PRINT_MODE == '<stderr>' then
		fp = io.stderr
	else
		fp = io.open(PRINT_MODE, 'w')
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
		if weight then
			line = line .. '  ' .. record.name
		else
			line = record.name
		end
		if number then
			local head = tostring(i)
			if head:len() < numsize then
				head = string.rep(' ', numsize - head:len()) .. head
			end
			line = head .. ':  ' .. line
		end
		if fp ~= nil then
			fp:write(line .. '\n')
		end
	end
	if PRINT_MODE:sub(1, 1) ~= '<' then
		if fp ~= nil then fp:close() end
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
	elseif #M == 1 then
		return M[1].name
	elseif Z_INTERACTIVE == 0 then
		return M[1].name
	end
	local retval = nil
	if Z_INTERACTIVE == 1 then
		PRINT_MODE = '<stderr>'
		z_print(M, true, true)
		io.stderr:write('> ')
		io.stderr:flush()
		local input = io.read('*l')
		if input == nil then
			return nil
		end
		local index = tonumber(input)
		if index == nil then
			return nil
		end
		if index < 1 or index > #M then
			return nil
		end
		retval = M[index].name
	elseif Z_INTERACTIVE == 2 then
		local fzf = os.getenv('_ZL_FZF')
		local tmpname = '/tmp/zlua.txt'
		local cmd = '--nth 2.. --reverse --inline-info +s --tac'
		local cmd = ((not fzf) and 'fzf' or fzf)  .. ' ' .. cmd
		if not windows then
			tmpname = os.tmpname()
			cmd = 'cat "' .. tmpname .. '" | ' .. cmd .. ' --height 35%'
		else
			tmpname = os.tmpname():gsub('\\', ''):gsub('%.', '')
			tmpname = os.getenv('TMP') .. '\\zlua_' .. tmpname .. '.txt'
			cmd = 'type "' .. tmpname .. '" | ' .. cmd
		end
		PRINT_MODE = tmpname
		z_print(M, true, false)
		retval = os.call(cmd)
		-- io.stderr:write('<'..cmd..'>\n')
		os.remove(tmpname)
		if retval == '' or retval == nil then
			return nil
		end
		local pos = retval:find(' ')
		if not pos then
			return nil
		end
		retval = retval:sub(pos, -1):gsub('^%s*', '')
	end
	return (retval ~= '' and retval or nil)
end


-----------------------------------------------------------------------
-- find_vcs_root
-----------------------------------------------------------------------
function find_vcs_root(path)
	local markers = os.getenv('_ZL_ROOT_MARKERS')
	local markers = markers and markers or '.git,.svn,.hg,.root'
	local markers = string.split(markers, ',')
	path = os.path.absolute(path)
	while true do
		for _, marker in ipairs(markers) do
			local test = os.path.join(path, marker)
			if os.path.exists(test) then
				return path
			end
		end
		local parent, _ = os.path.split(path)
		if path == parent then break end
		path = parent
	end
	return nil
end


-----------------------------------------------------------------------
-- cd to parent directories which contains keyword
-- #args == 0   -> returns to vcs root
-- #args == 1   -> returns to parent dir starts with args[1]
-- #args == 2   -> returns string.replace($PWD, args[1], args[2])
-----------------------------------------------------------------------
function cd_backward(args, options, pwd)
	local nargs = #args
	local pwd = (pwd ~= nil) and pwd or os.pwd()
	if nargs == 0 then
		return find_vcs_root(pwd)
	elseif nargs == 1 then
		local test = windows and pwd:gsub('\\', '/') or pwd
		local key = '/' .. args[1]
		if not key:match('%u') then
			test = test:lower()
		end
		local pos, _ = test:rfind(key)
		if not pos then
			return nil
		end
		local ends = test:find('/', pos + key:len())
		if not ends then
			ends = test:len()
		end
		local path = pwd:sub(1, (not ends) and test:len() or ends)
		return os.path.normpath(path)
	else
		local test = windows and pwd:gsub('\\', '/') or pwd
		local src = args[1]
		local dst = args[2]
		if not src:match('%u') then
			test = test:lower()
		end
		local start, ends = test:rfind(src)
		if not start then
			return pwd
		end
		local lhs = pwd:sub(1, start - 1)
		local rhs = pwd:sub(ends + 1)
		return lhs .. dst .. rhs
	end
end


-----------------------------------------------------------------------
-- cd forward
-----------------------------------------------------------------------
function cd_forward(args, options)
end


-----------------------------------------------------------------------
-- cd detour
-----------------------------------------------------------------------
function cd_forward(args, options)
end


-----------------------------------------------------------------------
-- main entry
-----------------------------------------------------------------------
function main(argv)
	local options, args = os.getopt(argv)
	os.log("main()")
	if options == nil then
		return false
	elseif table.length(args) == 0 and table.length(options) == 0 then
		print(os.argv[0] .. ': missing arguments')
		help = os.argv[-1] .. ' ' .. os.argv[0] .. ' --help'
		print('Try \'' .. help .. '\' for more information')
		return false
	end
	if true then
		os.log("options: " .. dump(options))
		os.log("args: " .. dump(args))
	end
	if options['-c'] then
		Z_SUBDIR = true
	end
	if options['-r'] then
		Z_METHOD = 'rank'
	elseif options['-t'] then
		Z_METHOD = 'time'
	end
	if options['-i'] then
		Z_INTERACTIVE = 1
	elseif options['-I'] then
		Z_INTERACTIVE = 2
	end
	if options['--cd'] or options['-e'] then
		local path = ''
		if options['-b'] then
			path = cd_backward(args, options)
		elseif options['-f'] then
			path = cd_forward(args, options)
		elseif options['-d'] then
			path = cd_detour(args, options)
		elseif #args == 0 then
			path = nil
		else
			path = z_cd(args)
			if path == nil and Z_MATCHMODE ~= 0 then
				local last = args[#args]
				if os.path.isdir(last) then
					path = os.path.abspath(last)
					path = os.path.norm(path)
				end
			end
		end
		if path ~= nil then
			io.write(path .. (options['-e'] and "\n" or ""))
		end
	elseif options['--add'] then
		-- print('data: ' .. DATA_FILE)
		z_add(args)
	elseif options['-x'] then
		z_remove(args)
	elseif options['--init'] then
		local opts = {}
		for _, key in ipairs(args) do
			opts[key] = 1
		end
		if windows then
			z_windows_init(opts)
		elseif opts.fish then
			z_fish_init(opts)
		else
			z_shell_init(opts)
		end
	elseif options['-l'] then
		local M = z_match(args and args or {}, Z_METHOD, Z_SUBDIR)
		if options['-s'] then
			z_print(M, false, false)
		else
			z_print(M, true, false)
		end
	elseif options['--complete'] then
		local line = args[1] and args[1] or ''
		local head = line:sub(Z_CMD:len()+1):gsub('^%s+', '')
		local M = z_match({head}, Z_METHOD, Z_SUBDIR)
		for _, item in pairs(M) do
			print(item.name)
		end
	elseif options['--help'] or options['-h'] then
		z_help()
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
	local _zl_cmd = os.getenv('_ZL_CMD')
	local _zl_matchname = os.getenv('_ZL_MATCH_NAME')
	local _zl_skippwd = os.getenv('_ZL_SKIP_PWD')
	local _zl_matchmode = os.getenv('_ZL_MATCH_MODE')
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
	if _zl_cmd ~= nil then
		Z_CMD = _zl_cmd
	end
	if _zl_matchname ~= nil then
		local m = string.lower(_zl_matchname)
		if (m == '1' or m == 'yes' or m == 'true' or m == 't') then
			Z_MATCHNAME = true
		end
	end
	if _zl_skippwd ~= nil then
		local m = string.lower(_zl_skippwd)
		if (m == '1' or m == 'yes' or m == 'true' or m == 't') then
			Z_SKIPPWD = true
		end
	end
	if _zl_matchmode ~= nil then
		local m = tonumber(_zl_matchmode)
		Z_MATCHMODE = m
		if (m == 1) then
			Z_MATCHNAME = true
			Z_SKIPPWD = true
		end
	end
end


-----------------------------------------------------------------------
-- initialize clink hooks
-----------------------------------------------------------------------
function z_clink_init()
	local once = os.getenv("_ZL_ADD_ONCE")
	local previous = ''
	function z_add_to_database()
		pwd = clink.get_cwd()
		if once then
			if previous == pwd then
				return
			end
			previous = pwd
		end
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
_zlua() {
	local arg_mode=""
	local arg_type=""
	local arg_subdir=""
	local arg_inter=""
	local arg_strip=""
	if [ "$1" = "--add" ]; then
		shift
		_ZL_RANDOM="$RANDOM" "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --add "$@"
		return
	elif [ "$1" = "--complete" ]; then
		shift
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --complete "$@"
		return
	fi
	while [ "$1" ]; do
		case "$1" in
			-l) local arg_mode="-l" ;;
			-e) local arg_mode="-e" ;;
			-x) local arg_mode="-x" ;;
			-t) local arg_type="-t" ;;
			-r) local arg_type="-r" ;;
			-c) local arg_subdir="-c" ;;
			-s) local arg_strip="-s" ;;
			-i) local arg_inter="-i" ;;
			-I) local arg_inter="-I" ;;
			-h|--help) local arg_mode="-h" ;;
			*) break ;;
		esac
		shift
	done
	if [ "$arg_mode" = "-h" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -h
	elif [ "$arg_mode" = "-l" ] || [ "$#" -eq 0 ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -l $arg_subdir $arg_type $arg_strip "$@"
	elif [ -n "$arg_mode" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" $arg_mode $arg_subdir $arg_type $arg_inter "$@"
	else
		local dest=$("$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --cd $arg_type $arg_subdir $arg_inter "$@")
		if [ -n "$dest" ] && [ -d "$dest" ]; then
			if [ -z "$_ZL_CD" ]; then
				builtin cd "$dest"
			else
				$_ZL_CD "$dest"
			fi
			if [ -n "$_ZL_ECHO" ]; then pwd; fi
		fi
	fi
}
# alias ${_ZL_CMD:-z}='_zlua 2>&1'
alias ${_ZL_CMD:-z}='_zlua'
]]

local script_init_bash = [[
case "$PROMPT_COMMAND" in
	*_zlua?--add*) ;;
	*) PROMPT_COMMAND="(_zlua --add \"\$(command pwd 2>/dev/null)\" &);$PROMPT_COMMAND" ;;
esac
]]

local script_init_bash_fast = [[
case "$PROMPT_COMMAND" in
	*_zlua?--add*) ;;
	*) PROMPT_COMMAND="(_zlua --add \"\$PWD\" &);$PROMPT_COMMAND" ;;
esac
]]

local script_init_bash_once = [[
_zlua_precmd() {
    [ "$_ZL_PREVIOUS_PWD" = "$PWD" ] && return
    _ZL_PREVIOUS_PWD="$PWD"
    (_zlua --add "$PWD" 2> /dev/null &)
}
case "$PROMPT_COMMAND" in
	*_zlua_precmd*) ;;
	*) PROMPT_COMMAND="_zlua_precmd;$PROMPT_COMMAND" ;;
esac
]]

local script_init_posix = [[
case "$PS1" in
	*_zlua?--add*) ;;
	*) PS1="\$(_zlua --add \"\$(command pwd 2>/dev/null)\" &)$PS1"
esac
]]

local script_init_posix_once = [[
_zlua_precmd() {
    [ "$_ZL_PREVIOUS_PWD" = "$PWD" ] && return
    _ZL_PREVIOUS_PWD="$PWD"
    (_zlua --add "$PWD" 2> /dev/null &)
}
case "$PS1" in
	*_zlua_precmd*) ;;
	*) PS1="\$(_zlua_precmd)$PS1"
esac
]]

local script_init_zsh = [[
_zlua_precmd() {
	(_zlua --add "${PWD:a}" &)
}
typeset -gaU precmd_functions
[ -n "${precmd_functions[(r)_zlua_precmd]}" ] || {
	precmd_functions[$(($#precmd_functions+1))]=_zlua_precmd
}
]]

local script_init_zsh_once = [[
_zlua_precmd() {
	(_zlua --add "${PWD:a}" &)
}
typeset -gaU chpwd_functions
[ -n "${chpwd_functions[(r)_zlua_precmd]}" ] || {
	chpwd_functions[$(($#chpwd_functions+1))]=_zlua_precmd
}
]]

local script_complete_bash = [[
if [ -n "$BASH_VERSION" ]; then
	complete -o filenames -C '_zlua --complete "$COMP_LINE"' ${_ZL_CMD:-z}
fi
]]

local script_complete_zsh = [[
_zlua_zsh_tab_completion() {
	# tab completion
	local compl
	read -l compl
	(( $+compstate )) && compstate[insert]=menu # no expand
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

	local prompt_hook = (os.getenv("_ZL_NO_PROMPT_COMMAND") == nil)
	local once = (os.getenv("_ZL_ADD_ONCE") ~= nil) or opts.once ~= nil

	if opts.bash ~= nil then
		if prompt_hook then
			if opts.once then
				print(script_init_bash_once)
			elseif opts.fast then
				print(script_init_bash_fast)
			else
				print(script_init_bash)
			end
		end
		print(script_complete_bash)
	elseif opts.zsh ~= nil then
		if prompt_hook then
			print(once and script_init_zsh_once or script_init_zsh)
		end
		print(script_complete_zsh)
	elseif opts.posix ~= nil then
		if prompt_hook then
			print(once and script_init_posix_once or script_init_posix)
		end
		print('_ZL_NO_BUILTIN_CD=1')
	else
		if prompt_hook then
			print('if [ -n "$BASH_VERSION" ]; then')
			if opts.once then
				print(script_init_bash_once)
			elseif opts.fast then
				print(script_init_bash_fast)
			else
				print(script_init_bash)
			end
			print(script_complete_bash)
			print('elif [ -n "$ZSH_VERSION" ]; then')
			print(once and script_init_zsh_once or script_init_zsh)
			-- print(script_complete_zsh)
			print('else')
			print(once and script_init_posix_once or script_init_posix)
			print('_ZL_NO_BUILTIN_CD=1')
			print('fi')
		end
	end
	if opts.enhanced ~= nil then
		print('export _ZL_MATCH_MODE=1')
	end
end


-----------------------------------------------------------------------
-- Fish shell init
-----------------------------------------------------------------------
local script_zlua_fish = [[
function _zlua
	set -l arg_mode ""
	set -l arg_type ""
	set -l arg_subdir ""
	set -l arg_inter ""
	set -l arg_strip ""
	function _zlua_call; eval (string escape -- $argv); end
	if test "$argv[1]" = "--add"
		set -e argv[1]
		set -x _ZL_RANDOM (random)
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --add $argv
		return
	else if test "$argv[1]" = "--complete"
		set -e argv[1]
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --complete $argv
		return
	end
	while true
		switch "$argv[1]"
			case "-l"; set arg_mode "-l"
			case "-e"; set arg_mode "-e"
			case "-x"; set arg_mode "-x"
			case "-t"; set arg_type "-t"
			case "-r"; set arg_type "-r"
			case "-c"; set arg_subdir "-c"
			case "-s"; set arg_strip "-s"
			case "-i"; set arg_inter "-i"
			case "-I"; set arg_inter "-I"
			case "-h"; set arg_mode "-h"
			case "--help"; set arg_mode "-h"
			case '*'; break
		end
		set -e argv[1]
	end
	if test "$arg_mode" = "-h"
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -h
	else if test "$arg_mode" = "-l"
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -l $arg_subdir $arg_type $arg_strip $argv
	else if test (count $argv) -eq 0
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -l $arg_subdir $arg_type $arg_strip $argv
	else if test -n "$arg_mode"
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" $arg_mode $arg_subdir $arg_type $arg_inter $argv
	else
		set -l dest (_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --cd $arg_type $arg_subdir $arg_inter $argv)
		if test -n "$dest" -a -d "$dest"
			if test -z "$_ZL_CD"
				builtin cd "$dest"
			else
				_zlua_call "$_ZL_CD" "$dest"
			end
		end
		if test -n "$_ZL_ECHO"; pwd; end
	end
end

if test -z "$_ZL_CMD"; set -x _ZL_CMD z; end
alias "$_ZL_CMD"=_zlua
]]

script_init_fish = [[
function _zlua_precmd --on-event fish_prompt
	_zlua --add "$PWD" 2> /dev/null &
end
]]

script_init_fish_once = [[
function _zlua_precmd --on-variable PWD
	_zlua --add "$PWD" 2> /dev/null &
end
]]

script_complete_fish = [[
function _z_complete
	eval "$_ZL_CMD" --complete (commandline -t)
end

complete -c $_ZL_CMD -f -a '(_z_complete)'
complete -c $_ZL_CMD -s 'r' -d 'cd to highest ranked dir matching'
complete -c $_ZL_CMD -s 'i' -d 'cd with interactive selection'
complete -c $_ZL_CMD -s 'I' -d 'cd with interactive selection using fzf'
complete -c $_ZL_CMD -s 't' -d 'cd to most recently accessed dir matching'
complete -c $_ZL_CMD -s 'l' -d 'list matches instead of cd'
complete -c $_ZL_CMD -s 'c' -d 'restrict matches to subdirs of $PWD'
complete -c $_ZL_CMD -s 'e' -d 'echo the best match, don''t cd'
complete -c $_ZL_CMD -s 'x' -x -d 'remove path from history' -a '(_z_complete)'
]]


function z_fish_init(opts)
	print('set -x ZLUA_SCRIPT "' .. os.scriptname() .. '"')
	print('set -x ZLUA_LUAEXE "' .. os.interpreter() .. '"')
	local once = (os.getenv("_ZL_ADD_ONCE") ~= nil) or opts.once ~= nil
	print(script_zlua_fish)
	if once then
		print(script_init_fish_once)
	else
		print(script_init_fish)
	end
	print(script_complete_fish)
	if opts.enhanced ~= nil then
		print('set -x _ZL_MATCH_MODE 1')
	end
end


-----------------------------------------------------------------------
-- windows .cmd script
-----------------------------------------------------------------------
local script_init_cmd = [[
set "MatchType=-n"
set "StrictSub=-n"
set "RunMode=-n"
set "StripMode="
set "InterMode="
if /i not "%_ZL_LUA_EXE%"=="" (
	set "LuaExe=%_ZL_LUA_EXE%"
)
:parse
if /i "%1"=="-r" (
	set "MatchType=-r"
	shift /1
	goto parse
)
if /i "%1"=="-t" (
	set "MatchType=-t"
	shift /1
	goto parse
)
if /i "%1"=="-c" (
	set "StrictSub=-c"
	shift /1
	goto parse
)
if /i "%1"=="-l" (
	set "RunMode=-l"
	shift /1
	goto parse
)
if /i "%1"=="-e" (
	set "RunMode=-e"
	shift /1
	goto parse
)
if /i "%1"=="-x" (
	set "RunMode=-x"
	shift /1
	goto parse
)
if "%1"=="-i" (
	set "InterMode=-i"
	shift /1
	goto parse
)
if "%1"=="-I" (
	set "InterMode=-I"
	shift /1
	goto parse
)
if /i "%1"=="-s" (
	set "StripMode=-s"
	shift /1
	goto parse
)
if /i "%1"=="-h" (
	call "%LuaExe%" "%LuaScript%" -h
	goto end
)
:check
if /i "%1"=="" (
	set "RunMode=-l"
)
for /f "delims=" %%i in ('cd') do set "PWD=%%i"
if /i "%RunMode%"=="-n" (
	for /f "delims=" %%i in ('call "%LuaExe%" "%LuaScript%" --cd %MatchType% %StrictSub% %InterMode% %*') do set "NewPath=%%i"
	if not "!NewPath!"=="" (
		if exist !NewPath!\nul (
			if /i not "%_ZL_ECHO%"=="" (
				echo !NewPath!
			)
			pushd !NewPath!
			pushd !NewPath!
			endlocal
			popd
		)
	)
)	else (
	call "%LuaExe%" "%LuaScript%" "%RunMode%" %MatchType% %StrictSub% %InterMode% %StripMode% %*
)
:end
]]

local script_init_powershell = [[
function Init-ZLua {

   # Prevent repeating init
   if ($global:_zlua_inited) {
      return
   }

   if (!$script:ZLUA_LUAEXE) {
      $script:ZLUA_LUAEXE = "lua.exe"
   }

   if (!$script:ZLUA_SCRIPT) {
      $script:ZLUA_SCRIPT = "z.lua"
   }

   if (!$env:_ZL_CD) {
      $env:_ZL_CD = "Push-Location"
   }

   if (!$env:_ZL_CMD) {
      $env:_ZL_CMD = "z"
   }

   function global:_zlua {
      $arg_mode = ""
      $arg_type = ""
      $arg_subdir = ""
      $arg_inter = ""
      $arg_strip = ""


      if ($args[0] -eq "--add") {
         $_, $rest = $args
         $env:_ZL_RANDOM = Get-Random
         & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT --add $rest
         return
      } elseif ($args[0] -eq "--complete") {
         $_, $rest = $args
         & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT --complete $rest
         return
      }

      $first = $args[0]
      :loop while ($first) {
         switch -casesensitive ($first) {
            "-l" {
               $arg_mode = "-l"
               break
            }
            "-e" {
               $arg_mode = "-e"
               break
            }
            "-x" {
               $arg_mode = "-x"
               break
            }
            "-t" {
               $arg_type = "-t"
               break
            }
            "-r" {
               $arg_type = "-r"
               break
            }
            "-c" {
               $arg_subdir="-c"
               break
            }
            "-s" {
               $arg_strip="-s"
               break
            }
            "-i" {
               $arg_inter="-i"
               break
            }
            "-I" {
               $arg_inter="-I"
               break
            }
            "-h" {
               $arg_mode="-h"
               break
            }
            "--help" {
               $arg_mode="-h"
               break
            }
            Default {
               break loop
            }
         }
         $_, $args = $args
         if(!$args) {
            break loop
         }
         $first = $args[0]
      }

      $env:PWD = ([string] $PWD)

      if ($arg_mode -eq "-h") {
         & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT -h
      } elseif ($arg_mode -eq "-l" -or $args.Length -eq 0) {
         & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT -l $arg_subdir $arg_type $arg_strip $args
      } elseif ($arg_mode -ne "") {
         & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT $arg_mode $arg_subdir $arg_type $arg_inter $args
      } else {
         $dest = & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT --cd $arg_type $arg_subdir $arg_inter $args
         if ($dest) {
            & $env:_ZL_CD "$dest"
            if ($env:_ZL_ECHO) {
               Write-Host $PWD
            }
         }
      }
   }

   Set-Alias $env:_ZL_CMD _zlua -Scope Global

   if (!$env:_ZL_NO_PROMPT_COMMAND) {
      $script:_zlua_orig_prompt = ([ref] $function:prompt)
      $script:_zlua_previous = ""
      function global:prompt {
         & $script:_zlua_orig_prompt.value
         $str_pwd = ([string] $PWD)
         if ((!$env:_ZL_ADD_ONCE) -or
               ($env:_ZL_ADD_ONCE -and ($script:_zlua_previous -ne $str_pwd))) {
            $script:_zlua_previous = $str_pwd
            _zlua --add $str_pwd
         }
      }
   }

   $global:_zlua_inited = $True
}

Init-ZLua
]]

-----------------------------------------------------------------------
-- initialize cmd
-----------------------------------------------------------------------
function z_windows_init(opts)
	if opts.powershell ~= nil then
		print('$LuaExe = "' .. os.interpreter() .. '"')
		print('$LuaScript = "' .. os.scriptname() .. '"')
		if opts.enhanced ~= nil then
			print('$env:_ZL_MATCH_MODE = 1')
		end
		if opts.once ~= nil then
			print('$env:_ZL_ADD_ONCE = 1')
		end
		print(script_init_powershell)
	else
		print('@echo off')
		print('setlocal EnableDelayedExpansion')
		print('set "LuaExe=' .. os.interpreter() .. '"')
		print('set "LuaScript=' .. os.scriptname() .. '"')
		print(script_init_cmd)
		if opts.newline then
			print('echo.')
		end
	end
end


-----------------------------------------------------------------------
-- help
-----------------------------------------------------------------------
function z_help()
	local cmd = Z_CMD .. ' '
	print(cmd .. 'foo       # cd to most frecent dir matching foo')
	print(cmd .. 'foo bar   # cd to most frecent dir matching foo and bar')
	print(cmd .. '-r bar    # cd to highest ranked dir matching foo')
	print(cmd .. '-t bar    # cd to most recently accessed dir matching foo')
	print(cmd .. '-l bar    # list matches instead of cd')
	print(cmd .. '-c foo    # restrict matches to subdirs of $PWD')
	print(cmd .. '-e foo    # echo the best match, don\'t cd')
	print(cmd .. '-x path   # remove path from history')
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
