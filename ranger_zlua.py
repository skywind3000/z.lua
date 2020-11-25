import time, sys, os
import ranger.api
import subprocess

old_hook_init = ranger.api.hook_init

PATH_LUA = os.environ.get('RANGER_LUA')
PATH_ZLUA = os.environ.get('RANGER_ZLUA')

if not PATH_LUA:
    for path in os.environ.get('PATH', '').split(os.path.pathsep):
        for name in ('lua', 'luajit', 'lua5.3', 'lua5.2', 'lua5.1'):
            test = os.path.join(path, name)
            test = test + (sys.platform[:3] == 'win' and ".exe" or "")
            if os.path.exists(test):
                PATH_LUA = test
                break

if not PATH_LUA:
    sys.stderr.write('Please install lua or set $RANGER_LUA.\n')
    sys.exit()

if (not PATH_ZLUA) or (not os.path.exists(PATH_ZLUA)):
    sys.stderr.write('Not find z.lua, please set $RANGER_ZLUA to absolute path of z.lua.\n')
    sys.exit()

            
def hook_init(fm):
    def update_zlua(signal):
        import os, random
        os.environ['_ZL_RANDOM'] = str(random.randint(0, 0x7fffffff))
        p = subprocess.Popen([PATH_LUA, PATH_ZLUA, "--add", signal.new.path])
        p.wait()
    if PATH_ZLUA and PATH_LUA and os.path.exists(PATH_ZLUA):
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
                cmd = '"%s" "%s" '%(PATH_LUA, PATH_ZLUA)
                if mode in ('-I', '-i', '--'):
                    cmd += ' --cd'
                for arg in args:
                    cmd += ' "%s"'%arg
                if mode in ('-e', '-x'):
                    path = subprocess.check_output([PATH_LUA, PATH_ZLUA, '--cd'] + args)
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
                path = subprocess.check_output([PATH_LUA, PATH_ZLUA, '--cd'] + args)
                path = path.decode("utf-8", "ignore")
                path = path.rstrip('\n')
                if path and os.path.exists(path):
                    self.fm.cd(path)
                else:
                    self.fm.notify('No matching found', bad = True)
        return True

