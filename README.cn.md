# z.lua

快速路径切换工具（类似 z.sh / autojump / fasd），兼容 Windows 和所有 Posix Shell 以及 Fish Shell，同时包含了众多功能改进。


## Description

z.lua 是一个快速路径切换工具，它会跟踪你在 shell 下访问过的路径，通过一套称为 Frecent 的机制（源自 FireFox），经过一段简短的学习之后，z.lua 会帮你跳转到所有匹配正则关键字的路径里 Frecent 值最高的那条路径去。

正则将按顺序进行匹配，"z foo bar" 可以匹配到 /foo/bar ，但是不能匹配 /bar/foo。


## Features

- 性能比 **z.sh** 快三倍，比 **fasd** / **autojump** 快十倍以上。
- 支持 Posix Shell（bash, zsh, dash, sh, ash, busybox）及 Fish Shell。
- 支持 Windows cmd 终端 (使用 clink)，cmder 和 ConEmu。
- 无依赖，不会像 fasd/z.sh 那样对 awk/gawk 有特殊的版本要求。
- 兼容 lua 5.1, 5.2 和 5.3 以上版本。
- 新增：环境变量 "$_ZL_ADD_ONCE" 设成 1 的话性仅当前路径改变时才更新数据库。
- 新增：增强匹配模式，将环境变量 "$_ZL_MATCH_MODE" 设置成 1 可以启用。
- 新增：交互选择模式，如果有多个匹配结果的话，跳转前允许你进行选择。


## Examples

```bash
z foo       # 跳转到包含 foo 并且权重（Frecent）最高的路径
z foo bar   # 跳转到同时包含 foo 和 bar 并且权重最高的路径
z -r foo    # 跳转到包含 foo 并且访问次数最高的路径
z -t foo    # 跳转到包含 foo 并且最近访问过的路径
z -l foo    # 不跳转，只是列出所有匹配 foo 的路径
z -c foo    # 跳转到包含 foo 并且是当前路径的子路径的权重最高的路径
z -e foo    # 不跳转，只是打印出匹配 foo 并且权重最高的路径
z -i foo    # 就进入交互式选择模式，让你自己挑选去哪里（多个结果的话）
```


## Install

- Posix Shells（Bash、zsh、dash、sh 或 BusyBox 等）：

  在你的 `.bashrc`, `.zshrc` 或者 `.profile` 文件中按 shell 类型添加对应语句：

      eval "$(lua /path/to/z.lua  --init bash)"   # BASH 初始化
      eval "$(lua /path/to/z.lua  --init zsh)"    # ZSH 初始化
      eval "$(lua /path/to/z.lua  --init posix)"  # Posix shell 初始化

  用下面参数初始化会进入“增强匹配模式”：

      eval "$(lua /path/to/z.lua  --init bash once enhanced)"   # BASH 初始化
      eval "$(lua /path/to/z.lua  --init zsh once enhanced)"    # ZSH 初始化
      eval "$(lua /path/to/z.lua  --init posix once enhanced)"  # Posix shell 初始化

  同时 zsh 支持 antigen/oh-my-zsh 等包管理器，可以用下面路径：

      skywind3000/z.lua

  进行安装，比如 antigen 的话，在 `.zshrc` 中加入：

      antigen bundle skywind3000/z.lua

  就可以了（主要要放在 antigen apply 语句之前）。


- Fish Shell:

  新建 `~/.config/fish/conf.d/z.fish` 文件，并包含如下代码：

      lua /path/to/z.lua --init fish | source

  Fish version `2.4.0` 或者以上版本都支持，还有一种初始化方法：

      lua /path/to/z.lua --init fish > ~/.config/fish/conf.d/z.fish

  但是第二种方法需要记得在 z.lua 位置改变或者 lua 版本升级后需要重新生成。

- Windows (with clink):

  - 将 z.lua 和 z.cmd 拷贝到 clink 的安装目录。
  - 将 clink 的安装目录添加到 `%PATH%` (z.cmd 可以被任意位置调用到)。
  - 保证 lua 命令在你的 `%PATH%` 环境变量中。
  

- Windows cmder:

  - 将 z.lua 和 z.cmd 拷贝到 cmder/vendor 目录中。
  - 将 cmder/vendor 添加到环境变量 `%PATH%` 里面。
  - 保证 lua 命令在你的 `%PATH%` 环境变量中。


## Options

- 设置 `$_ZL_CMD` 来改变命令名称 (默认为 z)。
- 设置 `$_ZL_DATA` 来改变数据文件 (default ~/.zlua)。
- 设置 `$_ZL_NO_PROMPT_COMMAND` 为 1 来跳过钩子函数初始化（方便自己处理）。
- 设置 `$_ZL_EXCLUDE_DIRS` 来确定一个你不想收集的路径数组。
- 设置 `$_ZL_ADD_ONCE` 为 '1' 时，仅在当前路径 `$PWD` 改变时才更新数据库。
- 设置 `$_ZL_MAXAGE` 来确定一个数据老化的阀值 (默认为 5000)。
- 设置 `$_ZL_CD` 用来指定你想用的 cd 命令，比如有人用 cd_func 。
- 设置 `$_ZL_ECHO` 为 1 可以在跳转后显示目标路径名称。
- 设置 `$_ZL_MATCH_MODE` 为 1 可以打开 “增强匹配模式”。

## Aging

`z.lua` 在数据库中为每条路径维护着一个称为 rank 的字段，用于记录每条历史路径的访问次数，每次访问某路径，该路径对应 rank 字段的值就会增加 1。随着被添加的路径越来越多，`z.lua` 使用一种称为 “数据老化” 的方式来控制数据的总量。即，每次更新数据库后，会将所有路径的 rank 值加起来，如果这个值大于 5000 （`$_ZL_MAXAGE`），所有路径的 rank 值都会乘以 0.9，然后剔除所有 rank 小于 1 的记录。


## Frecency

Frecency 是一个由 'recent' 和 'frequency' 组成的合成词，这个术语由 Mozilla 发明，用于同时兼顾访问的频率和上一次访问到现在的时间差（是否最近访问）两种情况。

对于 z.lua，一条路径如果访问次数过低，它的 rank 值就会比较低，但是如果它最近被访问过，那么它将迅速获得一个比其他曾经频繁访问但是最近没有访问过的路径更高的权重。Frecent 并不记录在数据库中，是运行的时候即时计算出来的。


## Matching

z.lua 提供两种路径匹配算法：

- 设置 $_ZL_MATCH_MODE=0：默认匹配算法，兼容 z.sh。
- 设置 $_ZL_MATCH_MODE=1：增强匹配算法，更懂你的高效匹配算法。

除了设置环境变量外，还可以通过：

    eval "$(lua /path/to/z.lua --init bash enhanced)"

来进入增强模式。


### 默认匹配

默认情况下 z.lua 使用和 z.sh 类似的匹配算法，成为默认匹配法。给定路径会按顺序匹配各个正则表达式。

- cd 到一个包含 foo 的路径:

      z foo

- cd 到一个以 foo 结尾的路径:

      z foo$

- 使用多个参数进行跳转:

  假设路径历史数据库（~/.zlua）中有两条记录：

      10   /home/user/work/inbox
      30   /home/user/mail/inbox

  `"z in"`将会跳转到 `/home/user/mail/inbox` 因为它有更高的权重，同时你可以传递更多参数给 z.lua 来更加精确的指明，如 `"z w in"` 则会让你跳到 `/home/user/work/inbox`。

### 增强匹配

你可以通过设置环境变量来启用增强匹配模式:

    export _ZL_MATCH_MODE=1

或者时候使用下面语句：

    eval "$(lua /path/to/z.lua --init bash enhanced)"

进行初始化，他们是等效的，记得把上面的 bash 可以根据你的 shell 改为 `zsh` 或者 `posix`。



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
lua /path/to/z.lua --init fish once | source
````

It could be much faster on slow hardware or Cygwin/MSYS.


## Tips

Recommended aliases you may find useful:

```bash
alias zc='z -c'      # restrict matches to subdirs of $PWD
alias zz='z -i'      # cd with interactive selection
```

And you can define a `zf` command to select history path with fzf:

```bash
alias zf='cd "$(z -l -s | fzf --reverse --height 35%)"'
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


## Credit

Releated projects:

- [rupa/z](https://github.com/rupa/z): origin z.sh implementation
- [JannesMeyer/z.ps](https://github.com/JannesMeyer/z.ps): z for powershell


## License

Licensed under MIT license.

