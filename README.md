# z.lua

z - jump around (lua implementation for running on both unix &amp; windows)


## Features

- 10x times faster than fasd and autojump
- 3x times faster than z.sh
- supports posix shells: bash, zsh, dash, sh, busybox, and etc.
- supports Windows cmd (with clink) and cmder

## USE

```bash
z foo       # cd to most frecent dir matching foo
z foo bar   # cd to most frecent dir matching foo and bar
z -r foo    # cd to highest ranked dir matching foo
z -t foo    # cd to most recently accessed dir matching foo
z -l foo    # list matches instead of cd
z -c foo    # restrict matches to subdirs of $PWD
z -e foo    # echo the best match, don't cd
```

## Install

- bash:
  put something like this in your `.bashrc`:
      eval "$(lua /path/to/z.lua --init bash)"

- zsh:
  put something like this in your `.zshrc`:
      eval "$(lua /path/to/z.lua --init zsh)"

- posix shells:
  put something like this in your `.profile`:
      eval "$(lua /path/to/z.lua --init posix)"

- Windows (with clink):
  copy z.lua and z.cmd to clink's home directory
  Add clink's home to `%PATH%` (z.cmd can be called anywhere)
  Ensure that "lua" can be called in `%PATH%`

- Windows Cmder Install:
  copy z.lua and z.cmd to cmder/vendor
  Add cmder/vendor to %PATH%
  Ensure that "lua" can be called in %PATH%

## Customize

- set $_ZL_CMD in .bashrc/.zshrc to change the command (default z).
- set $_ZL_DATA in .bashrc/.zshrc to change the datafile (default ~/.zlua).
- set $_ZL_NO_PROMPT_COMMAND if you're handling PROMPT_COMMAND yourself.
- set $_ZL_EXCLUDE_DIRS to an array of directories to exclude.

## Credit

Licensed under MIT license.