import neovim
import json
import socket
import os
import subprocess
@neovim.plugin
class Ensime(object):
    def __init__(self, vim):
        self.browse = False
        self.vim = vim
    def get_cache_port(self, where):
        f = open(".ensime_cache/" + where)
        port = f.read()
        f.close()
        return port.replace("\n", "")
    def get_socket(self):
        s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        port = self.get_cache_port("bridge")
        s.connect(("::1", int(port)))
        return s
    def send(self, what):
        s = self.get_socket()
        s.send(what + "\n")
        s.close()
    def cursor(self):
        return self.vim.current.window.cursor
    def path_start_size(self, what):
        self.vim.command("normal e")
        e = self.cursor()[1]
        self.vim.command("normal b")
        b = self.cursor()[1]
        s = e - b
        self.send('{} "{}", {}, {}, {}'.format(what,
            self.vim.current.buffer.name, self.cursor()[0], b + 1, s))
    @neovim.command('EnType', range='', nargs='*', sync=True)
    def type(self, args, range):
        self.path_start_size("type")
    @neovim.command('EnDocUri', range='', nargs='*', sync=True)
    def doc_uri(self, args, range):
        self.path_start_size("doc_uri")
    @neovim.command('EnDocBrowse', range='', nargs='*', sync=True)
    def doc_browse(self, args, range):
        self.browse = True
        self.doc_uri(args, range)
    def log(self, what):
        f = open("/tmp/a", "a")
        f.write(what + "\n")
        f.close()
    def read_line(self, s):
        ret = ''
        while True:
            c = s.recv(1)
            if c == '\n' or c == '':
                break
            else:
                ret += c
        return ret
    def message(self, m):
        self.vim.command("echo '{}'".format(m))
    def handle_payload(self, payload):
        typehint = payload["typehint"]
        if typehint == "BasicTypeInfo":
            self.message(payload["fullName"])
        elif typehint == "StringResponse":
            url = "http://127.0.0.1:{}/{}".format(self.get_cache_port("http"),
                    payload["text"])
            if self.browse:
                subprocess.Popen([os.environ.get("BROWSER"), url])
                self.browse = False
            self.message(url)
    @neovim.autocmd('CursorMoved', pattern='*.scala', eval='expand("<afile>")',
                    sync=True)
    def unqueue(self, filename):
        s = self.get_socket()
        s.send("unqueue\n")
        while True:
            result = self.read_line(s)
            if result == None or result == "nil":
                break
            self.log("> " + str(result))
            _json = json.loads(result)
            if _json["payload"] != None:
                self.handle_payload(_json["payload"])
        s.close()
    def autocmd_handler(self, filename):
        self._increment_calls()
        self.vim.current.line = (
            'Autocmd: Called %s times, file: %s' % (self.calls, filename))
