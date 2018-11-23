# z.lua

z - jump around (lua implementation for running on both unix &amp; windows).

An alternative to [z.sh](https://github.com/rupa/z) with windows and posix shells support and performance improving.


## Features

- **10x** times faster than **fasd** and **autojump**
- **3x** times faster than **z.sh**
- available for **posix shells**: bash, zsh, dash, sh, ash, busybox and etc.
- supports Windows cmd (with clink) and cmder
- self contained, no dependence on awk/gawk
- compatible with lua 5.1, 5.2 and 5.3+

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

  (sh, ash, dash and busybox have been tested)

- Windows (with clink):

  - copy z.lua and z.cmd to clink's home directory
  - Add clink's home to `%PATH%` (z.cmd can be called anywhere)
  - Ensure that "lua" can be called in `%PATH%`

- Windows cmder:

  - copy z.lua and z.cmd to cmder/vendor
  - Add cmder/vendor to `%PATH%`
  - Ensure that "lua" can be called in `%PATH%`


## Customize

- set `$_ZL_CMD` in .bashrc/.zshrc to change the command (default z).
- set `$_ZL_DATA` in .bashrc/.zshrc to change the datafile (default ~/.zlua).
- set `$_ZL_NO_PROMPT_COMMAND` if you're handling PROMPT_COMMAND yourself.
- set `$_ZL_EXCLUDE_DIRS` to an array of directories to exclude.

## Benchmark

The slowest part of all autojump tools is path tracking, which is installed in your `$PROMPT_COMMAND` and will be invoked each time you press enter (each time before bash display prompt). So I profile them on my NAS:

```bash
$ time autojump --add /tmp
real    0m0.352s
user    0m0.077s
sys     0m0.185s

$ time fasd -A /tmp
real    0m0.618s
user    0m0.076s
sys     0m0.242s

$ time _z --add /tmp
real    0m0.194s
user    0m0.046s
sys     0m0.154s

$ time _zlua --add /tmp
real    0m0.052s
user    0m0.015s
sys     0m0.030s
```

As you see, z.lua is the fastest one and requires less resource.


## Credit

Releated projects:

- [rupa/z](https://github.com/rupa/z): origin z.sh implementation
- [JannesMeyer/z.ps](https://github.com/JannesMeyer/z.ps): z for powershell


## License

Licensed under MIT license.

