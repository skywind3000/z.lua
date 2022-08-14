import time, sys, os
import ranger.api
import subprocess

# $RANGER_LUA and $RANGER_ZLUA variables are deprecated, do not use them.
ZLUA_LUAEXE = os.environ.get('RANGER_LUA') or os.environ.get('ZLUA_LUAEXE')
ZLUA_SCRIPT = os.environ.get('RANGER_ZLUA') or os.environ.get('ZLUA_SCRIPT')

if not ZLUA_LUAEXE:
    for path in os.environ.get('PATH', '').split(os.path.pathsep):
        for name in ('lua', 'luajit', 'lua5.3', 'lua5.2', 'lua5.1'):
            test = os.path.join(path, name)
            test = test + (sys.platform[:3] == 'win' and ".exe" or "")
            if os.path.exists(test):
                ZLUA_LUAEXE = test
                break

def _report_error(msg):
    sys.stderr.write('ranger_zlua: ' + msg)
    raise RuntimeError(msg)

if not ZLUA_LUAEXE:
    _report_error('Please install lua in $PATH or make sure $ZLUA_LUAEXE points to a lua executable.\n')
if (not ZLUA_SCRIPT) or (not os.path.exists(ZLUA_SCRIPT)):
    _report_error('Could not find z.lua, please make sure $ZLUA_SCRIPT is set to absolute path of z.lua.\n')


# Inform z.lua about directories the user browses to inside ranger
old_hook_init = ranger.api.hook_init

def hook_init(fm):
    def update_zlua(signal):
        import os, random
        os.environ['_ZL_RANDOM'] = str(random.randint(0, 0x7fffffff))
        p = subprocess.Popen([ZLUA_LUAEXE, ZLUA_SCRIPT, "--add", signal.new.path])
        p.wait()
    if ZLUA_SCRIPT and ZLUA_LUAEXE and os.path.exists(ZLUA_SCRIPT):
        fm.signal_bind('cd', update_zlua)
    return old_hook_init(fm)

ranger.api.hook_init = hook_init


class z(ranger.api.commands.Command):
    def execute (self):
        import sys, os, time
        args = self.args[1:]
        if args:
            mode = ''
            for arg in args:
                if arg in ('-l', '-e', '-x', '-h', '--help', '--'):
                    mode = arg
                    break
                elif arg in ('-I', '-i'):
                    mode = arg
                elif arg[:1] != '-':
                    break
            if mode:
                cmd = '"%s" "%s" '%(ZLUA_LUAEXE, ZLUA_SCRIPT)
                if mode in ('-I', '-i', '--'):
                    cmd += ' --cd'
                for arg in args:
                    cmd += ' "%s"'%arg
                if mode in ('-e', '-x'):
                    path = subprocess.check_output([ZLUA_LUAEXE, ZLUA_SCRIPT, '--cd'] + args)
                    path = path.decode("utf-8", "ignore")
                    path = path.rstrip('\n')
                    self.fm.notify(path)
                elif mode in ('-h', '-l', '--help'):
                    p = self.fm.execute_command(cmd + '| less +G', universal_newlines=True)
                    stdout, stderr = p.communicate()
                elif mode == '--':
                    p = self.fm.execute_command(cmd + ' 2>&1 | less +G', universal_newlines=True)
                    stdout, stderr = p.communicate()
                else:
                    p = self.fm.execute_command(cmd, universal_newlines=True, stdout=subprocess.PIPE)
                    stdout, stderr = p.communicate()
                    path = stdout.rstrip('\n')
                    self.fm.execute_console('redraw_window')
                    if path and os.path.exists(path):
                        self.fm.cd(path)
            else:
                path = subprocess.check_output([ZLUA_LUAEXE, ZLUA_SCRIPT, '--cd'] + args)
                path = path.decode("utf-8", "ignore")
                path = path.rstrip('\n')
                if path and os.path.exists(path):
                    self.fm.cd(path)
                else:
                    self.fm.notify('No matching found', bad = True)
        return True

