#! /usr/bin/env lua
--=====================================================================
--
-- z.lua - a cd command that learns, by skywind 2018-2022
-- Licensed under MIT license.
--
-- Version 1.8.16, Last Modified: 2022/07/21 22:12
--
-- * 10x faster than fasd and autojump, 3x faster than z.sh
-- * available for posix shells: bash, zsh, sh, ash, dash, busybox
-- * available for fish shell, power shell and windows cmd
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
--     * z -I foo   # cd with interactive selection using fzf
--     * z -b foo   # cd to the parent directory starting with foo
--
-- Bash Install:
--     * put something like this in your .bashrc:
--         eval "$(lua /path/to/z.lua --init bash)"
--
-- Bash Enhanced Mode:
--     * put something like this in your .bashrc:
--         eval "$(lua /path/to/z.lua --init bash enhanced)"
--
-- Bash fzf tab completion Mode:
--     * put something like this in your .bashrc:
--         eval "$(lua /path/to/z.lua --init bash fzf)"
--
-- Zsh Install:
--     * put something like this in your .zshrc:
--         eval "$(lua /path/to/z.lua --init zsh)"
--
-- Posix Shell Install:
--     * put something like this in your .profile:
--         eval "$(lua /path/to/z.lua --init posix)"
--
-- Fish Shell Install:
--     * put something like this in your config file:
--         source (lua /path/to/z.lua --init fish | psub)
--
-- Power Shell Install:
--     * put something like this in your config file:
--         Invoke-Expression (& { 
--           (lua /path/to/z.lua --init powershell) -join "`n" })
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
-- Windows WSL-1:
--     * Install lua-filesystem module before init z.lua:
--         sudo apt-get install lua-filesystem
--
-- Configure (optional):
--   set $_ZL_CMD in .bashrc/.zshrc to change the command (default z).
--   set $_ZL_DATA in .bashrc/.zshrc to change the datafile (default ~/.zlua).
--   set $_ZL_NO_PROMPT_COMMAND if you're handling PROMPT_COMMAND yourself.
--   set $_ZL_EXCLUDE_DIRS to a comma separated list of dirs to exclude.
--   set $_ZL_ADD_ONCE to 1 to update database only if $PWD changed.
--   set $_ZL_CD to specify your own cd command
--   set $_ZL_ECHO to 1 to display new directory name after cd.
--   set $_ZL_MAXAGE to define a aging threshold (default is 5000).
--   set $_ZL_MATCH_MODE to 1 to enable enhanced matching mode.
--   set $_ZL_NO_CHECK to 1 to disable path validation. z --purge to clear.
--   set $_ZL_USE_LFS to 1 to use lua-filesystem package
--   set $_ZL_HYPHEN to 1 to stop treating hyphen as a regexp keyword
--
--=====================================================================


-----------------------------------------------------------------------
-- Module Header
-----------------------------------------------------------------------
local modname = 'z'
local MM = {}
_G[modname] = MM
package.loaded[modname] = MM  --return modname
setmetatable(MM, {__index = _G})

if _ENV ~= nil then
	_ENV[modname] = MM
else
	setfenv(1, MM)
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
Z_HYPHEN = false

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

function string:endswith(text)
	return text == "" or self:sub(-#text) == text
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
	if key == '' then
		return self:len(), 0
	end
	local length = self:len()
	local start, ends = self:reverse():find(key:reverse(), 1, true)
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
	local func = function(table, level) end
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
-- ffi optimize (luajit has builtin ffi module)
-----------------------------------------------------------------------
os.native = {}
os.native.status, os.native.ffi =  pcall(require, "ffi")
if os.native.status then
	local ffi = os.native.ffi
	if windows then
		ffi.cdef[[
		int GetFullPathNameA(const char *name, uint32_t size, char *out, char **name);
		int ReplaceFileA(const char *dstname, const char *srcname, void *, uint32_t, void *, void *);
		uint32_t GetTickCount(void);
		uint32_t GetFileAttributesA(const char *name);
		uint32_t GetCurrentDirectoryA(uint32_t size, char *ptr);
		uint32_t GetShortPathNameA(const char *longname, char *shortname, uint32_t size);
		uint32_t GetLongPathNameA(const char *shortname, char *longname, uint32_t size);
		]]
		local kernel32 = ffi.load('kernel32.dll')
		local buffer = ffi.new('char[?]', 4100)
		local INVALID_FILE_ATTRIBUTES = 0xffffffff
		local FILE_ATTRIBUTE_DIRECTORY = 0x10
		os.native.kernel32 = kernel32
		function os.native.GetFullPathName(name)
			local hr = kernel32.GetFullPathNameA(name, 4096, buffer, nil)
			return (hr > 0) and ffi.string(buffer, hr) or nil
		end
		function os.native.ReplaceFile(replaced, replacement)
			local hr = kernel32.ReplaceFileA(replaced, replacement, nil, 2, nil, nil)
			return (hr ~= 0) and true or false
		end
		function os.native.GetTickCount()
			return kernel32.GetTickCount()
		end
		function os.native.GetFileAttributes(name)
			return kernel32.GetFileAttributesA(name)
		end
		function os.native.GetLongPathName(name)
			local hr = kernel32.GetLongPathNameA(name, buffer, 4096)
			return (hr ~= 0) and ffi.string(buffer, hr) or nil
		end
		function os.native.GetShortPathName(name)
			local hr = kernel32.GetShortPathNameA(name, buffer, 4096)
			return (hr ~= 0) and ffi.string(buffer, hr) or nil
		end
		function os.native.GetRealPathName(name)
			local short = os.native.GetShortPathName(name)
			if short then
				return os.native.GetLongPathName(short)
			end
			return nil
		end
		function os.native.exists(name)
			local attr = os.native.GetFileAttributes(name)
			return attr ~= INVALID_FILE_ATTRIBUTES
		end
		function os.native.isdir(name)
			local attr = os.native.GetFileAttributes(name)
			local isdir = FILE_ATTRIBUTE_DIRECTORY
			if attr == INVALID_FILE_ATTRIBUTES then
				return false
			end
			return (attr % (2 * isdir)) >= isdir
		end
		function os.native.getcwd()
			local hr = kernel32.GetCurrentDirectoryA(4096, buffer)
			if hr <= 0 then return nil end
			return ffi.string(buffer, hr)
		end
	else
		ffi.cdef[[
		typedef struct { long tv_sec; long tv_usec; } timeval;
		int gettimeofday(timeval *tv, void *tz);
		int access(const char *name, int mode);
		char *realpath(const char *path, char *resolve);
		char *getcwd(char *buf, size_t size);
		]]
		local timeval = ffi.new('timeval[?]', 1)
		local buffer = ffi.new('char[?]', 4100)
		function os.native.gettimeofday()
			local hr = ffi.C.gettimeofday(timeval, nil)
			local sec = tonumber(timeval[0].tv_sec)
			local usec = tonumber(timeval[0].tv_usec)
			return sec + (usec * 0.000001)
		end
		function os.native.access(name, mode)
			return ffi.C.access(name, mode)
		end
		function os.native.realpath(name)
			local path = ffi.C.realpath(name, buffer)
			return (path ~= nil) and ffi.string(buffer) or nil
		end
		function os.native.getcwd()
			local hr = ffi.C.getcwd(buffer, 4099)
			return hr ~= nil and ffi.string(buffer) or nil
		end
	end
	function os.native.tickcount() 
		if windows then
			return os.native.GetTickCount()
		else
			return math.floor(os.native.gettimeofday() * 1000)
		end
	end
	os.native.init = true
end


-----------------------------------------------------------------------
-- get current path
-----------------------------------------------------------------------
function os.pwd()
	if os.native and os.native.getcwd then
		local hr = os.native.getcwd()
		if hr then return hr end
	end
	if os.getcwd then
		return os.getcwd()
	end
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
	if os.native and os.native.GetFullPathName then
		local test = os.native.GetFullPathName(path)
		if test then return test end
	end
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
			test = os.call('realpath \'' .. path .. '\' 2> /dev/null')
			if test ~= nil and test ~= '' then
				return test
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
		for _, python in pairs({'python3', 'python2', 'python'}) do
			local s = 'sys.stdout.write(os.path.abspath(sys.argv[1]))'
			local s = '-c "import os, sys;' .. s .. '" \'' .. path .. '\''
			local s = python .. ' ' .. s
			local test = os.path.which(python)
			if test ~= nil and test ~= '' then
				test = os.call(s)
				if test ~= nil and test ~= '' then
					return test
				end
			end
		end
	end
	return os.path.absolute(path)
end


-----------------------------------------------------------------------
-- dir exists
-----------------------------------------------------------------------
function os.path.isdir(pathname)
	if pathname == '/' then
		return true
	elseif pathname == '' then
		return false
	elseif windows then
		if pathname == '\\' then
			return true
		end
	end
	if os.native and os.native.isdir then
		return os.native.isdir(pathname)
	end
	if clink and os.isdir then
		return os.isdir(pathname)
	end
	local name = pathname
	if (not name:endswith('/')) and (not name:endswith('\\')) then
		name = name .. os.path.sep
	end
	return os.path.exists(name)
end


-----------------------------------------------------------------------
-- file or path exists
-----------------------------------------------------------------------
function os.path.exists(name)
	if name == '/' then
		return true
	end
	if os.native and os.native.exists then
		return os.native.exists(name)
	end
	local ok, err, code = os.rename(name, name)
	if not ok then
		if code == 13 or code == 17 then
			return true
		elseif code == 30 then
			local f = io.open(name,"r")
			if f ~= nil then
				io.close(f)
				return true
			end
		elseif name:sub(-1) == '/' and code == 20 and (not windows) then
			local test = name .. '.'
			ok, err, code = os.rename(test, test)
			if code == 16 or code == 13 or code == 22 then
				return true
			end
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
		elseif pos ~= nil and p2 ~= nil then
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
		if pos == 3 and drive ~= '' then
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
-- get environ
-----------------------------------------------------------------------
function os.environ(name, default)
	local value = os.getenv(name)
	if os.envmap ~= nil and type(os.envmap) == 'table' then
		local t = os.envmap[name]
		value = (t ~= nil and type(t) == 'string') and t or value
	end
	if value == nil then
		return default
	elseif type(default) == 'boolean' then
		value = value:lower()
		if value == '0' or value == '' or value == 'no' then
			return false
		elseif value == 'false' or value == 'n' or value == 'f' then
			return false
		else
			return true
		end
	elseif type(default) == 'number' then
		value = tonumber(value)
		if value == nil then 
			return default 
		else
			return value
		end
	elseif type(default) == 'string' then
		return value
	elseif type(default) == 'table' then
		return value:sep(',')
	end
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
			if arg == '-' then
				options['-'] = ''
			elseif arg == '--' then
				options['-'] = '-'
			elseif arg:match('^-%d+$') then
				options['-'] = arg:sub(2)
			else
				local part = arg:split('=')
				options[part[1]] = part[2] ~= nil and part[2] or ''
			end
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
	seed = seed .. tostring(os.clock() * 10000000)
	if os.native and os.native.tickcount then
		seed = seed .. tostring(os.native.tickcount())
	end
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
	local fp = io.open(os.path.expand(filename), 'r')
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
	math.random_init()
	while true do
		tmpname = filename .. '.' .. tostring(os.time())
		if os.native and os.native.tickcount then
			local key = os.native.tickcount() % 1000
			tmpname = tmpname .. string.format('%03d', key)
			tmpname = tmpname .. math.random_string(5)
		else
			tmpname = tmpname .. math.random_string(8)
		end
		if not os.path.exists(tmpname) then
			-- print('tmpname: '..tmpname)
			break
		end
	end
	if windows then
		if os.native and os.native.ReplaceFile then
			fp = io.open(tmpname, 'w')
		else
			fp = io.open(filename, 'w')
			tmpname = nil
		end
	else
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
		if windows then
			local ok, err, code = os.rename(tmpname, filename)
			if not ok then
				os.native.ReplaceFile(filename, tmpname)
			end
		else
			os.rename(tmpname, filename)
		end
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
		local start, endup = pathname:find(pat, pos)
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
			local start, endup = last:find(pat, 1)
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
		if Z_HYPHEN then
			p = p:gsub('-', '%%-')
		end
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
	local nc = os.getenv('_ZL_NO_CHECK')
	if nc == nil or nc == '' or nc == '0' then
		M = data_filter(M)
	end
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
				if windows then
					if os.native and os.native.GetRealPathName then
						local ts = os.native.GetRealPathName(path)
						if ts then
							path = ts
						end
					end
				end
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
	local insensitive = path_case_insensitive()
	for _, path in pairs(paths) do
		path = os.path.abspath(path)
		if not insensitive then
			remove[path] = 1
		else
			remove[path:lower()] = 1
		end
	end
	for i = 1, #M do
		local item = M[i]
		if not insensitive then
			if not remove[item.name] then
				table.insert(X, item)
			end
		else
			if not remove[item.name:lower()] then
				table.insert(X, item)
			end
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
	M = data_filter(M)
	if Z_MATCHNAME then
		local N = data_select(M, patterns, true)
		N = data_filter(N)
		if #N > 0 then
			M = N
		end
	end
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
	local maxsize = 9
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
		local size = #patterns
		if size <= 1 then
			return os.path.norm(last)
		elseif last ~= '/' and last ~= '\\' then
			return os.path.norm(last)
		end
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
	if os.environ('_ZL_INT_SORT', false) then
		table.sort(M, function (a, b) return a.name < b.name end)
	end
	local retval = nil
	if Z_INTERACTIVE == 1 then
		PRINT_MODE = '<stderr>'
		z_print(M, true, true)
		io.stderr:write('> ')
		io.stderr:flush()
		local input = io.read('*l')
		if input == nil or input == '' then
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
		local fzf = os.environ('_ZL_FZF', 'fzf')
		local tmpname = '/tmp/zlua.txt'
		local cmd = '--nth 2.. --reverse --info=inline --tac '
		local flag = os.environ('_ZL_FZF_FLAG', '')
		flag = (flag == '' or flag == nil) and '+s -e' or flag
		cmd = ((fzf == '') and 'fzf' or fzf)  .. ' ' .. cmd .. ' ' .. flag
		if not windows then
			tmpname = os.tmpname()
			local height = os.environ('_ZL_FZF_HEIGHT', '35%')
			if height ~= nil and height ~= '' and height ~= '0' then
				cmd = cmd .. ' --height ' .. height
			end
			cmd = cmd .. ' < "' .. tmpname .. '"'
		else
			tmpname = os.tmpname():gsub('\\', ''):gsub('%.', '')
			tmpname = os.environ('TMP', '') .. '\\zlua_' .. tmpname .. '.txt'
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
-- purge invalid paths
-----------------------------------------------------------------------
function z_purge()
	local M = data_load(DATA_FILE)
	local N = data_filter(M)
	local x = #M
	local y = #N
	if x == y then
		return x, y
	end
	data_save(DATA_FILE, N)
	return x, y
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
		if args[1]:sub(1, 2) == '..' then
			local size = args[1]:len() - 1
			if args[1]:match('^%.%.+$') then
				size = args[1]:len() - 1
			elseif args[1]:match('^%.%.%d+$') then
				size = tonumber(args[1]:sub(3))
			else
				return nil
			end
			local path = pwd
			for index = 1, size do
				path = os.path.join(path, '..')
			end
			return os.path.normpath(path)
		else
			pwd = os.path.split(pwd)
			local test = windows and pwd:gsub('\\', '/') or pwd
			local key = windows and args[1]:lower() or args[1]
			if not key:match('%u') then
				test = test:lower()
			end
			local pos, ends = test:rfind('/' .. key)
			if pos then
				ends = test:find('/', pos + key:len() + 1, true)
				ends = ends and ends or test:len()
				return os.path.normpath(pwd:sub(1, ends))
			elseif windows and test:startswith(key) then
				ends = test:find('/', key:len(), true)
				ends = ends and ends or test:len()
				return os.path.normpath(pwd:sub(1, ends))
			end
			pos = test:rfind(key)
			if pos then
				ends = test:find('/', pos + key:len(), true)
				ends = ends and ends or test:len()
				return os.path.normpath(pwd:sub(1, ends))
			end
			return nil
		end
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
-- cd minus: "z -", "z --", "z -2"
-----------------------------------------------------------------------
function cd_minus(args, options)
	Z_SKIPPWD = true
	local M = z_match({}, 'time', Z_SUBDIR)
	local size = #M
	if options['-'] == '-' then
		for i, item in ipairs(M) do
			if i > 10 then break end
			io.stderr:write(' ' .. tostring(i - 1) .. '  ' .. item.name .. '\n')
		end
	else
		local level = 0
		local num = options['-']
		if num and num ~= '' then
			level = tonumber(num)
		end
		if level >= 0 and level < size then
			return M[level + 1].name
		end
	end
	return nil
end


-----------------------------------------------------------------------
-- cd breadcrumbs: z -b -i, z -b -I
-----------------------------------------------------------------------
function cd_breadcrumbs(pwd, interactive)
	local pwd = (pwd == nil or pwd == '') and os.pwd() or pwd
	local pwd = os.path.normpath(pwd)
	local path, _ = os.path.split(pwd)
	local elements = {}
	local interactive = interactive and interactive or 1
	local fullname = os.environ('_ZL_FULL_PATH', false)
	while true do
		local head, name = os.path.split(path)
		if head == path  then		-- reached root
			table.insert(elements, {head, head})
			break
		elseif name ~= '' then
			table.insert(elements, {name, path})
		else
			break
		end
		path = head
	end
	local tmpname = '/tmp/zlua.txt'
	local fp = io.stderr
	if interactive == 2 then
		if not windows then
			tmpname = os.tmpname()
		else
			tmpname = os.tmpname():gsub('\\', ''):gsub('%.', '')
			tmpname = os.environ('TMP', '') .. '\\zlua_' .. tmpname .. '.txt'
		end
		fp = io.open(tmpname, 'w')
	end
	-- print table
	local maxsize = string.len(tostring(#elements))
	for i = #elements, 1, -1 do
		local item = elements[i]
		local name = item[1]
		local text = string.rep(' ', maxsize - string.len(i)) .. tostring(i)
		text = text .. ': ' .. (fullname and item[2] or item[1])
		fp:write(text .. '\n')
	end
	if fp ~= io.stderr then
		fp:close()
	end
	local retval = ''
	-- select from stdin or fzf
	if interactive == 1 then
		io.stderr:write('> ')
		io.stderr:flush()
		retval = io.read('*l')
	elseif interactive == 2 then
		local fzf = os.environ('_ZL_FZF', 'fzf')
		local cmd = '--reverse --info=inline --tac '
		local flag = os.environ('_ZL_FZF_FLAG', '')
		flag = (flag == '' or flag == nil) and '+s -e' or flag
		cmd = ((fzf == '') and 'fzf' or fzf) .. ' ' .. cmd .. ' ' .. flag
		if not windows then
			local height = os.environ('_ZL_FZF_HEIGHT', '35%')
			if height ~= nil and height ~= '' and height ~= '0' then
				cmd = cmd .. ' --height ' .. height
			end
			cmd = cmd .. '< "' .. tmpname .. '"'
		else
			cmd = 'type "' .. tmpname .. '" | ' .. cmd
		end
		retval = os.call(cmd)
		os.remove(tmpname)
		if retval == '' or retval == nil then
			return nil
		end
		local pos = retval:find(':')
		if not pos then
			return nil
		end
		retval = retval:sub(1, pos - 1):gsub('^%s*', '')
	end
	local index = tonumber(retval)
	if index == nil or index < 1 or index > #elements then
		return nil
	end
	return elements[index][2]
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
			if Z_INTERACTIVE == 0 then
				path = cd_backward(args, options)
			else
				path = cd_breadcrumbs('', Z_INTERACTIVE)
			end
		elseif options['-'] then
			path = cd_minus(args, options)
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
	elseif options['--purge'] then
		local src, dst = z_purge()
		local fp = io.stderr
		fp:write('purge: ' .. tostring(src) .. ' record(s) remaining, ')
		fp:write(tostring(src - dst) .. ' invalid record(s) removed.\n')
	elseif options['--init'] then
		local opts = {}
		for _, key in ipairs(args) do
			opts[key] = 1
		end
		if windows then
			z_windows_init(opts)
		elseif opts.fish then
			z_fish_init(opts)
		elseif opts.powershell then
		       z_windows_init(opts)
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
	local _zl_exclude = os.getenv('_ZL_EXCLUDE_DIRS')
	local _zl_cmd = os.getenv('_ZL_CMD')
	local _zl_matchname = os.getenv('_ZL_MATCH_NAME')
	local _zl_skippwd = os.getenv('_ZL_SKIP_PWD')
	local _zl_matchmode = os.getenv('_ZL_MATCH_MODE')
	local _zl_hyphen = os.getenv('_ZL_HYPHEN')
	if _zl_data ~= nil and _zl_data ~= "" then
		if windows then
			DATA_FILE = _zl_data
		else
			-- avoid windows environments affect cygwin & msys
			if not string.match(_zl_data, '^%a:[/\\]') then
				DATA_FILE = _zl_data
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
		local part = _zl_exclude:split(',')
		local insensitive = path_case_insensitive()
		for _, name in ipairs(part) do
			if insensitive then
				name = name:lower()
			end
			if windows then
				name = os.path.norm(name)
			end
			table.insert(Z_EXCLUDE, name)
		end
	end
	if _zl_cmd ~= nil and _zl_cmd ~= '' then
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
	if _zl_hyphen ~= nil then
		local m = string.lower(_zl_hyphen)
		if (m == '1' or m == 'yes' or m == 'true' or m == 't') then
			Z_HYPHEN = true
		end
	end
end


-----------------------------------------------------------------------
-- initialize clink hooks
-----------------------------------------------------------------------
function z_clink_init()
	local once = os.environ("_ZL_ADD_ONCE", false)
	local _zl_clink_prompt_priority = os.environ('_ZL_CLINK_PROMPT_PRIORITY', 99)
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
	clink.prompt.register_filter(z_add_to_database, _zl_clink_prompt_priority)
	function z_match_completion(word)
		local M = z_match({word}, Z_METHOD, Z_SUBDIR)
		for _, item in pairs(M) do
			clink.add_match(item.name)
		end
		return {}
	end
	local z_parser = clink.arg.new_parser()
	z_parser:set_arguments({ z_match_completion })
	z_parser:set_flags("-c", "-r", "-i", "--cd", "-e", "-b", "--add", "-x", "--purge", 
		"--init", "-l", "-s", "--complete", "--help", "-h")
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
			--purge) local arg_mode="--purge" ;;
			*) break ;;
		esac
		shift
	done
	if [ "$arg_mode" = "-h" ] || [ "$arg_mode" = "--purge" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" $arg_mode
	elif [ "$arg_mode" = "-l" ] || [ "$#" -eq 0 ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -l $arg_subdir $arg_type $arg_strip "$@"
	elif [ -n "$arg_mode" ]; then
		"$ZLUA_LUAEXE" "$ZLUA_SCRIPT" $arg_mode $arg_subdir $arg_type $arg_inter "$@"
	else
		local zdest=$("$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --cd $arg_type $arg_subdir $arg_inter "$@")
		if [ -n "$zdest" ] && [ -d "$zdest" ]; then
			if [ -z "$_ZL_CD" ]; then
				builtin cd "$zdest"
			else
				$_ZL_CD "$zdest"
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
	*) PROMPT_COMMAND="(_zlua --add \"\$(command pwd 2>/dev/null)\" &)${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
]]

local script_init_bash_fast = [[
case "$PROMPT_COMMAND" in
	*_zlua?--add*) ;;
	*) PROMPT_COMMAND="(_zlua --add \"\$PWD\" &)${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
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
	*) PROMPT_COMMAND="_zlua_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
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
typeset -ga precmd_functions
[ -n "${precmd_functions[(r)_zlua_precmd]}" ] || {
	precmd_functions[$(($#precmd_functions+1))]=_zlua_precmd
}
]]

local script_init_zsh_once = [[
_zlua_precmd() {
	(_zlua --add "${PWD:a}" &)
}
typeset -ga chpwd_functions
[ -n "${chpwd_functions[(r)_zlua_precmd]}" ] || {
	chpwd_functions[$(($#chpwd_functions+1))]=_zlua_precmd
}
]]

local script_complete_bash = [[
if [ -n "$BASH_VERSION" ]; then
	complete -o filenames -C '_zlua --complete "$COMP_LINE"' ${_ZL_CMD:-z}
fi
]]

local script_fzf_complete_bash = [[
if [ "$TERM" != "dumb" ] && command -v fzf >/dev/null 2>&1; then
	# To redraw line after fzf closes (printf '\e[5n')
	bind '"\e[0n": redraw-current-line'
	_zlua_fzf_complete() {
		local selected=$(_zlua -l "${COMP_WORDS[@]:1}" | sed "s|$HOME|\~|" | $zlua_fzf | sed 's/^[0-9,.]* *//')
		if [ -n "$selected" ]; then
			COMPREPLY=( "$selected" )
		fi
		printf '\e[5n'
	}
	complete -o bashdefault -o nospace -F _zlua_fzf_complete ${_ZL_CMD:-z}
fi
]]

local script_complete_zsh = [[
_zlua_zsh_tab_completion() {
	# tab completion
	(( $+compstate )) && compstate[insert]=menu # no expand
	local -a tmp=(${(f)"$(_zlua --complete "${words/_zlua/z}")"})
	_describe "directory" tmp -U
}
if [ "${+functions[compdef]}" -ne 0 ]; then
	compdef _zlua_zsh_tab_completion _zlua 2> /dev/null
fi
]]


-----------------------------------------------------------------------
-- initialize bash/zsh
----------------------------------------------------------------------
function z_shell_init(opts)
	print('ZLUA_SCRIPT="' .. os.scriptname() .. '"')
	print('ZLUA_LUAEXE="' .. os.interpreter() .. '"')
	print('')
	if not opts.posix then
		print(script_zlua)
	elseif not opts.legacy then
		local script = script_zlua:gsub('builtin ', '')
		print(script)
	else
		local script = script_zlua:gsub('local ', ''):gsub('builtin ', '')
		print(script)
	end

	local prompt_hook = (not os.environ("_ZL_NO_PROMPT_COMMAND", false))
	local once = os.environ("_ZL_ADD_ONCE", false) or opts.once ~= nil

	if opts.clean ~= nil then
		prompt_hook = false
	end

	if opts.bash ~= nil then
		if prompt_hook then
			if once then
				print(script_init_bash_once)
			elseif opts.fast then
				print(script_init_bash_fast)
			else
				print(script_init_bash)
			end
		end
		print(script_complete_bash)
		if opts.fzf ~= nil then
			fzf_cmd = "fzf --nth 2.. --reverse --info=inline --tac "
			local height = os.environ('_ZL_FZF_HEIGHT', '35%')
			if height ~= nil and height ~= '' and height ~= '0' then
				fzf_cmd = fzf_cmd .. ' --height ' .. height .. ' '
			end
			local flag = os.environ('_ZL_FZF_FLAG', '')
			flag = (flag == '' or flag == nil) and '+s -e' or flag
			fzf_cmd = fzf_cmd .. ' ' .. flag .. ' '
			print('zlua_fzf="' .. fzf_cmd .. '"')
			print(script_fzf_complete_bash)
		end
	elseif opts.zsh ~= nil then
		if prompt_hook then
			print(once and script_init_zsh_once or script_init_zsh)
		end
		print(script_complete_zsh)
	elseif opts.posix ~= nil then
		if prompt_hook then
			local script = script_init_posix
			if once then script = script_init_posix_once end
			if opts.legacy then
				script = script:gsub('%&%)', ')')
			end
			print(script)
		end
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
			print('builtin() { cd "$2"; }')
			print('fi')
		end
	end
	if opts.enhanced ~= nil then
		print('export _ZL_MATCH_MODE=1')
	end
	if opts.nc then
		print('export _ZL_NO_CHECK=1')
	end
	if opts.echo then
		print('_ZL_ECHO=1')
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
			case "--purge"; set arg_mode "--purge"
			case '*'; break
		end
		set -e argv[1]
	end
	if test "$arg_mode" = "-h"
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" -h
	else if test "$arg_mode" = "--purge"
		_zlua_call "$ZLUA_LUAEXE" "$ZLUA_SCRIPT" --purge
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
			if test -n "$_ZL_ECHO"; pwd; end
		end
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
complete -c $_ZL_CMD -s 'b' -d 'jump backwards to given dir or to project root'
complete -c $_ZL_CMD -s 'x' -x -d 'remove path from history' -a '(_z_complete)'
]]


function z_fish_init(opts)
	print('set -x ZLUA_SCRIPT "' .. os.scriptname() .. '"')
	print('set -x ZLUA_LUAEXE "' .. os.interpreter() .. '"')
	local once = (os.getenv("_ZL_ADD_ONCE") ~= nil) or opts.once ~= nil
	local prompt_hook = (not os.environ("_ZL_NO_PROMPT_COMMAND", false))
	if opts.clean ~= nil then
		prompt_hook = false
	end
	print(script_zlua_fish)
	if prompt_hook then
		if once then
			print(script_init_fish_once)
		else
			print(script_init_fish)
		end
	end
	print(script_complete_fish)
	if opts.enhanced ~= nil then
		print('set -x _ZL_MATCH_MODE 1')
	end
	if opts.echo then
		print('set -g _ZL_ECHO 1')
	end
	if opts.nc then
		print('set -x _ZL_NO_CHECK 1')
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
if /i "%1"=="--add" (
	set "RunMode=--add"
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
if /i "%1"=="--purge" (
	call "%LuaExe%" "%LuaScript%" --purge
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
			goto popdir
		)
	)
)	else (
	call "%LuaExe%" "%LuaScript%" "%RunMode%" %MatchType% %StrictSub% %InterMode% %StripMode% %*
)
goto end
:popdir
popd
setlocal
set "NewPath=%CD%"
set "CDCmd=cd /d"
if /i not "%_ZL_CD%"=="" (
	set "CDCmd=%_ZL_CD%"
)
endlocal & popd & %CDCmd% "%NewPath%"
:end
]]


-----------------------------------------------------------------------
-- powershell
-----------------------------------------------------------------------
local script_zlua_powershell = [[
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
	} elseif ($args[0] -eq "--update") {
		$str_pwd = ([string] $PWD)
		if ((!$env:_ZL_ADD_ONCE) -or
			($env:_ZL_ADD_ONCE -and ($script:_zlua_previous -ne $str_pwd))) {
			$script:_zlua_previous = $str_pwd
			_zlua --add $str_pwd
		}
		return
	}
	:loop while ($args) {
		switch -casesensitive ($args[0]) {
			"-l" { $arg_mode = "-l"; break }
			"-e" { $arg_mode = "-e"; break }
			"-x" { $arg_mode = "-x"; break }
			"-t" { $arg_type = "-t"; break }
			"-r" { $arg_type = "-r"; break }
			"-c" { $arg_subdir="-c"; break }
			"-s" { $arg_strip="-s"; break }
			"-i" { $arg_inter="-i"; break }
			"-I" { $arg_inter="-I"; break }
			"-h" { $arg_mode="-h"; break }
			"--help" { $arg_mode="-h"; break }
			"--purge" { $arg_mode="--purge"; break }
			Default { break loop }
		}
		$_, $args = $args
		if (!$args) { break loop }
	}
	$env:PWD = ([string] $PWD)
	if ($arg_mode -eq "-h" -or $arg_mode -eq "--purge") {
		& $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT $arg_mode
	} elseif ($arg_mode -eq "-l" -or $args.Length -eq 0) {
		& $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT -l $arg_subdir $arg_type $arg_strip $args
	} elseif ($arg_mode -ne "") {
		& $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT $arg_mode $arg_subdir $arg_type $arg_inter $args
	} else {
		$dest = & $script:ZLUA_LUAEXE $script:ZLUA_SCRIPT --cd $arg_type $arg_subdir $arg_inter $args
		if ($dest) {
			if ($env:_ZL_CD) { & $env:_ZL_CD "$dest" }
			else { & "Push-Location" "$dest" }
			if ($env:_ZL_ECHO) { Write-Host $PWD }
		}
	}
}

if ($env:_ZL_CMD) { Set-Alias $env:_ZL_CMD _zlua -Scope Global }
else { Set-Alias z _zlua -Scope Global }
]]

local script_init_powershell = [[
if (!$env:_ZL_NO_PROMPT_COMMAND -and (!$global:_zlua_inited)) {
	$script:_zlua_orig_prompt = ([ref] $function:prompt)
	$global:_zlua_inited = $True
	function global:prompt {
		& $script:_zlua_orig_prompt.value
		_zlua --update
	}
}
]]


-----------------------------------------------------------------------
-- initialize cmd/powershell
-----------------------------------------------------------------------
function z_windows_init(opts)
	local prompt_hook = (not os.environ("_ZL_NO_PROMPT_COMMAND", false))
	if opts.clean ~= nil then
		prompt_hook = false
	end
	if opts.powershell ~= nil then
		print('$script:ZLUA_LUAEXE = "' .. os.interpreter() .. '"')
		print('$script:ZLUA_SCRIPT = "' .. os.scriptname() .. '"')
		print(script_zlua_powershell)
		if opts.enhanced ~= nil then
			print('$env:_ZL_MATCH_MODE = 1')
		end
		if opts.once ~= nil then
			print('$env:_ZL_ADD_ONCE = 1')
		end
		if opts.echo ~= nil then
			print('$env:_ZL_ECHO = 1')
		end
		if opts.nc ~= nil then
			print('$env:_ZL_NO_CHECK = 1')
		end
		if prompt_hook then
			print(script_init_powershell)
		end
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
	print(cmd .. '-r foo    # cd to highest ranked dir matching foo')
	print(cmd .. '-t foo    # cd to most recently accessed dir matching foo')
	print(cmd .. '-l foo    # list matches instead of cd')
	print(cmd .. '-c foo    # restrict matches to subdirs of $PWD')
	print(cmd .. '-e foo    # echo the best match, don\'t cd')
	print(cmd .. '-x path   # remove path from history')
	print(cmd .. '-i foo    # cd with interactive selection')
	print(cmd .. '-I foo    # cd with interactive selection using fzf')
	print(cmd .. '-b foo    # cd to the parent directory starting with foo')
end


-----------------------------------------------------------------------
-- LFS optimize
-----------------------------------------------------------------------
os.lfs = {}
os.lfs.enable = os.getenv('_ZL_USE_LFS')
os.lfs.enable = '1'
if os.lfs.enable ~= nil then
	local m = string.lower(os.lfs.enable)
	if (m == '1' or m == 'yes' or m == 'true' or m == 't') then
		os.lfs.status, os.lfs.pkg = pcall(require, 'lfs')
		if os.lfs.status then
			local lfs = os.lfs.pkg
			os.path.exists = function (name)
				return lfs.attributes(name) and true or false
			end
			os.path.isdir = function (name)
				local mode = lfs.attributes(name)
				if not mode then 
					return false
				end
				return (mode.mode == 'directory') and true or false
			end
		end
	end
end


-----------------------------------------------------------------------
-- program entry
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

-- vim: set ts=4 sw=4 tw=0 noet :

