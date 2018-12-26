# z.lua

z - jump around (lua implementation for unix &amp; windows).

An alternative to [z.sh](https://github.com/rupa/z) with windows and posix shells support and performance improving.


## Features

- **10x** times faster than **fasd** and **autojump**
- **3x** times faster than **z.sh**
- available for **posix shells**: bash, zsh, dash, sh, ash, busybox and etc.
- supports Windows cmd (with clink) and cmder
- self contained, no dependence on awk/gawk
- compatible with lua 5.1, 5.2 and 5.3+
- new "$_ZL_ADD_ONCE" to allow updating database only if `$PWD` changed.

## USE

```bash
z foo       # cd to most frecent dir matching foo
z foo bar   # cd to most frecent dir matching foo and bar
z -r foo    # cd to highest ranked dir matching foo
z -t foo    # cd to most recently accessed dir matching foo
z -l foo    # list matches instead of cd
z -c foo    # restrict matches to subdirs of $PWD
z -e foo    # echo the best match, don't cd
z -i foo    # cd with interactive selection
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
- set `$_ZL_ADD_ONCE` to '1' to update database only if `$PWD` changed.
- set `$_ZL_MAXAGE` to define a aging threshold (default is 5000).
- set `$_ZL_CD` to specify your own cd command.
- set `$_ZL_ECHO` to 1 to display new directory name after cd.



## Benchmark

The slowest part is adding path to history data file. It will run every time when you press enter (installed in $PROMPT_COMMAND). so I profile it on my nas:

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


## Add once

By default, z.lua will add current directory to database each time before display command prompt (correspond with z.sh). But there is an option to allow z.lua add path only if current working directory changed. 

To enable this, you can set `$_ZL_ADD_ONCE` to `1` before init z.lua. Or you can init z.lua on linux like this:

````bash
eval "$(lua /path/to/z.lua --init bash once)"
eval "$(lua /path/to/z.lua --init zsh once)"
````

It could be much faster on slow hardware or Cygwin/MSYS.


## Aliases

Recommanded aliases you may find useful:

```bash
alias zc='z -c'      # restrict matches to subdirs of $PWD
alias zz='z -i'      # cd with interactive selection
```

And you can define a `zf` command to select history path with fzf:

```bash
alias zf='cd "$(z -l -s | fzf --reverse --height 35%)"'
```


## Credit

Releated projects:

- [rupa/z](https://github.com/rupa/z): origin z.sh implementation
- [JannesMeyer/z.ps](https://github.com/JannesMeyer/z.ps): z for powershell


## License

Licensed under MIT license.

