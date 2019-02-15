@echo off
setlocal EnableDelayedExpansion

set "HomeDir=%~dp0"
set "PathSave=%PATH%"
set "LuaExe=lua"
set "LuaScript=%HomeDir%z.lua"
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
			popd
		)
	)
)	else (
	call "%LuaExe%" "%LuaScript%" "%RunMode%" %MatchType% %StrictSub% %InterMode% %StripMode% %*
)

:end
echo.

