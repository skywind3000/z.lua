# z.lua

A command line tool which helps you navigate faster by learning your habits :zap:

An alternative to [z.sh](https://github.com/rupa/z) with windows and posix shells support and various improvements.

【[README in Chinese | 中文文档](README.cn.md)】


## Description

z.lua is a faster way to navigate your filesystem. It tracks your most used directories, based on 'frecency'.  After  a  short  learning  phase, z will take you to the most 'frecent' directory that matches ALL of the regexes given on the command line, in order.

For example, `z foo bar` would match `/foo/bar` but not `/bar/foo`.


## Features

- **10x** times faster than **fasd** and **autojump**
- **3x** times faster than **z.sh**
- Available for **posix shells**: bash, zsh, dash, sh, ash, busybox and etc.
- Supports Windows cmd (with clink) and cmder
- Supports fish shell (2.4.0 +)
- Self contained, no dependence on awk/gawk
- Compatible with lua 5.1, 5.2 and 5.3+
- New "$_ZL_ADD_ONCE" to allow updating database only if `$PWD` changed.
- Enhanced matching mode with "$_ZL_MATCH_MODE" set to 1.
- Interactive selection enables you to choose where to go before cd.


## Examples

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

  It can also be initialized from "skywind3000/z.lua" with your zsh plugin managers (antigen / oh-my-zsh).

- posix shells:

  put something like this in your `.profile`:

      eval "$(lua /path/to/z.lua --init posix)"

  (sh, ash, dash and busybox have been tested)

- fish:

  Create `~/.config/fish/conf.d/z.fish` with following code

      source (lua /path/to/z.lua --init fish | psub)

  Fish version `2.4.0` or above is required. 

      lua /path/to/z.lua --init fish > ~/.config/fish/conf.d/z.fish

  This is another way to initiaze z.lua in fish shell, but remember to regenerate z.fish if z.lua has been updated or moved.

- Windows (with clink):

  - copy z.lua and z.cmd to clink's home directory
  - Add clink's home to `%PATH%` (z.cmd can be called anywhere)
  - Ensure that "lua" can be called in `%PATH%`

- Windows cmder:

  - copy z.lua and z.cmd to cmder/vendor
  - Add cmder/vendor to `%PATH%`
  - Ensure that "lua" can be called in `%PATH%`


## Options

- set `$_ZL_CMD` in .bashrc/.zshrc to change the command (default z).
- set `$_ZL_DATA` in .bashrc/.zshrc to change the datafile (default ~/.zlua).
- set `$_ZL_NO_PROMPT_COMMAND` if you're handling PROMPT_COMMAND yourself.
- set `$_ZL_EXCLUDE_DIRS` to an array of directories to exclude.
- set `$_ZL_ADD_ONCE` to '1' to update database only if `$PWD` changed.
- set `$_ZL_MAXAGE` to define a aging threshold (default is 5000).
- set `$_ZL_CD` to specify your own cd command.
- set `$_ZL_ECHO` to 1 to display new directory name after cd.
- set `$_ZL_MATCH_MODE` to 1 to enable enhanced matching.

## Aging

The rank of directories maintained by z.lua undergoes aging based on a simple formula. The rank of each entry is incremented  every  time  it  is accessed.  When the sum of ranks is over 5000 (`$_ZL_MAXAGE`), all ranks are multiplied by 0.9. Entries with a rank lower than 1 are forgotten.


## Frecency

Frecency is a portmanteau of 'recent' and 'frequency'. It is a weighted rank that depends on how often and how recently something occurred. As far as I know, Mozilla came up with the term.

To z.lua, a directory that has low ranking but has been accessed recently will quickly  have higher rank than a directory accessed frequently a long time ago. Frecency is determined at runtime.


## Matching

z.lua has two different matching methods: 0 for default, 1 for enhanced:


### Default matching

By default, z.lua uses default matching method similar to the original z.sh. Paths must be match all of the regexes in order.

- cd to a directory contains foo:

      z foo

- cd to a directory ends with foo:

      z foo$

- use multiple arguments:

  Assuming the following database:

      10   /home/user/work/inbox
      30   /home/user/mail/inbox

  `"z in"` would cd into `/home/user/mail/inbox` as the higher weighted entry. However you can pass multiple arguments to z.lua to prefer a different entry. In the above example, `"z w in"` would then change directory to `/home/user/work/inbox`.

### Enhanced matching

Enhanced matching can be enabled by export the environment:

    export _ZL_MATCH_MODE=1

For a given set of queries (the set of command-line arguments passed to z.lua), a path is a match if and only if:

1. Queries match the path in order (same as default method).
2. The last query matches the last segment of the path.

If no match is found, it will fall back to default matching method.

- match the last segment of the path:

  Assuming the following database:

      10   /home/user/workspace
      20   /home/user/workspace/project1
      30   /home/user/workspace/project2
      40   /home/user/workspace/project3

  If you use `"z wo"` in enhanced matching mode, only the `/home/user/work` will be matched, because according to rule No.2 it is the only path whose last segment matches `"wo"`.

  Since the last segment of a path is always easier to be recalled, it is sane to give it higher priority. You can also achieve this by typing `"z space$"` in both methods, but `"z wo"` is easier to type.

  Tips for rule No.2: 

  - If you want your last query **not only** to match the last segment of the path, append '$' as the last query. eg. `"z wo $"`. 
  - If you want your last query **not** to match the last segment of the path, append '/' as the last query. eg. `"z wo /"`.
 

- cd to the existent path if there is no match:

  Sometimes if you use:

      z foo

  And there is no matching result in the database, but there is an existent directory which can be accessed with the name "foo" from current directory, "`z foo`" will just work as:

      cd foo

  So, in the enhanced matching method, you can always use `z` like `cd` to change directory even if the new directory is untracked (haven't been accessed).

- Skip the current directory:

  when you are calling `z xxx` but the best match is the current directory, z.lua will choose the 2nd best match result for you. Assuming the database:

      10   /Users/Great_Wall/.rbenv/versions/2.4.1/lib/ruby/gems
      20   /Library/Ruby/Gems/2.0.0/gems

  When I use `z gems` by default, it will take me to `/Library/Ruby/Gems/2.0.0/gems`, but it's not what I want, so I press up arrow and execute `z gems` again, it will take me to `/Users/Great_Wall/.rbenv/versions/2.4.1/lib/ruby/gems` and this what I want.

  Of course I can always use `z env gems` to indicate what I want precisely. Skip the current directory means when you use `z xxx` you always want to change directory instead of stay in the same directory and do nothing if current directory is the best match.

The default matching method is designed to be compatible with original z.sh, but the enhanced matching method is much more handy and exclusive to z.lua.


## Add once

By default, z.lua will add current directory to database each time before display command prompt (correspond with z.sh). But there is an option to allow z.lua add path only if current working directory changed.

To enable this, you can set `$_ZL_ADD_ONCE` to `1` before init z.lua. Or you can init z.lua on linux like this:

````bash
eval "$(lua /path/to/z.lua --init bash once)"
eval "$(lua /path/to/z.lua --init zsh once)"
source (lua /path/to/z.lua --init fish | psub)
````

It could be much faster on slow hardware or Cygwin/MSYS.

## Interective selection

When there are multiple matches found, using `z -i` will display a list:

```bash
$ z -i soft
3:  0.25        /home/data/software
2:  3.75        /home/skywind/tmp/comma/software
1:  21          /home/skywind/software
> {CURSOR}
```

And then you can input the number and choose where to go before actual cd. eg. input 3 to cd to `/home/data/software`. And if you just press ENTER and input nothing, it will just quit and stay where you were.


## Tips

Recommended aliases you may find useful:

```bash
alias zc='z -c'      # restrict matches to subdirs of $PWD
alias zz='z -i'      # cd with interactive selection
```

And you can define a `zf` command to select history path with fzf:

```bash
zf() { 
 cd "$(z -l "$@" 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac | sed 's/^[0-9,.]* *//')" 
}
```



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


## Import database

You can import your datafile from z.sh by：


```bash
cat ~/.z >> ~/.zlua
```

Import datafile from autojump by：

```bash
FN="$HOME/.local/share/autojump/autojump.txt"
awk -F '\t' '{print $2 "|" $1 "|" 0}' $FN >> ~/.zlua
```


## Credit

Releated projects:

- [rupa/z](https://github.com/rupa/z): origin z.sh implementation
- [JannesMeyer/z.ps](https://github.com/JannesMeyer/z.ps): z for powershell


## License

Licensed under MIT license.

