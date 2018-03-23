@echo off
set "HomeDir=%~dp0"
set "PathSave=%PATH%"
set "LuaExe=lua"
set "LuaScript=%HomeDir%z.lua"
set "MatchType=-n"
set "StrictSub=-n"
set "ListOnly=-n"
set "HelpMode=-n"

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
	set "ListOnly=-l"
	shift /1
	goto parse
)

if /i "%1"=="-h" (
	call "%LuaExe%" "%LuaScript%" -h
	shift /1
	goto end
)

:check

if /i "%1"=="" (
	set "ListOnly=-l"
)

for /f "delims=" %%i in ('cd') do set "PWD=%%i"

if /i "%ListOnly%"=="-n" (
	setlocal EnableDelayedExpansion
	for /f "delims=" %%i in ('call "%LuaExe%" "%LuaScript%" --cd %MatchType% %StrictSub% %*') do set "NewPath=%%i"
	if not "!NewPath!"=="" (
		if exist !NewPath!\nul (
			pushd !NewPath!
			pushd !NewPath!
			endlocal
			popd
		)
	)
)	else (
	call "%LuaExe%" "%LuaScript%" -l %MatchType% %StrictSub% %*
)

:end

set "LuaExe="
set "LuaScript="
set "MatchType="
set "StrictSub="
set "NewPath="
set "ListOnly="
set "PWD="


