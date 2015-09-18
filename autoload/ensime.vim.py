import sys
import os
import inspect

def EnsimeInitPath():
    path = os.path.abspath(inspect.getfile(inspect.currentframe()))
    if path.endswith('/rplugin/python/ensime.py'): # nvim rplugin
        sys.path.append(os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(path)))))
    elif path.endswith('/autoload/ensime.vim.py'): # vim plugin
        sys.path.append(os.path.join(
            os.path.dirname(os.path.dirname(path))))

EnsimeInitPath()

import vim
import json
import os
import subprocess
import re
import logging
import time
import datetime
import thread
import inspect
import Queue
class Error:
    def __init__(self, message, l, c, e):
        self.message = message
        self.l = l
        self.c = c
        self.e = e
    def includes(self, cursor):
        return cursor[0] == self.l and self.c <= cursor[1] and cursor[1] < self.e
class Ensime(object):
    def module_exists(self, module_name):
        try:
            __import__(module_name)
        except ImportError:
            return False
        else:
            return True
    def log(self, what):
        log_dir = "/tmp/"
        if os.path.isdir(self.ensime_cache):
            log_dir = self.ensime_cache
        f = open(log_dir + "ensime-vim.log", "a")
        f.write("{}: {}\n".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f"), what))
        f.close()
    def unqueue_poll(self):
        while True:
            if self.ws != None:
                result = self.ws.recv()
                self.queue.put(result)
            time.sleep(1)
    def __init__(self, vim):
        self.ensime_cache = ".ensime_cache/"
        self.log("__init__: in")
        self.callId = 0
        self.browse = False
        self.vim = vim
        self.matches = []
        self.errors = []
        self.vim.command("highlight EnError ctermbg=red gui=underline")
        self.vim.command("let g:EnErrorStyle='EnError'")
        self.is_setup = False
        self.suggests = None
        self.ensime = None
        self.no_teardown = False
        self.open_definition = False
        self.ws = None
        self.queue = Queue.Queue()
        thread.start_new_thread(self.unqueue_poll, ())
    def ensime_bridge(self, action):
        binary = os.environ.get("ENSIME_BRIDGE")
        if binary == None: binary = "ensime_bridge"
        binary = (binary + " " + action)
        self.log("ensime_bridge: lanching " + binary) 
        subprocess.Popen(binary.split())
    def start_ensime_launcher(self):
        if self.ensime == None:
            self.ensime = EnsimeLauncher(".ensime", self.vim)
        if self.ensime.classpath != None:
            self.log("starting up ensime")
            self.message("ensime startup")
            self.ensime.run()
            return True
        else:
           self.log("launching EnsimeLauncher.setup()")
           self.ensime.setup()
           self.log("done launching EnsimeLauncher.setup()")
        return False
    def stop_ensime_launcher(self):
        self.ensime.stop()
        f = open(self.ensime_cache + "server.pid")
        pid = f.read()
        f.close()
        self.vim.command("!kill {}".format(pid))
    def teardown(self, filename):
        self.log("teardown: in")
        if os.path.exists(".ensime") and not self.no_teardown:
            self.stop_ensime_launcher()
            #self.ensime_bridge("stop")
    def setup(self):
        self.log("setup: in")
        if os.path.exists(".ensime") and not self.is_setup:
            if self.start_ensime_launcher():
                self.vim.command("set completefunc=EnCompleteFunc")
                self.is_setup = True
        if self.ensime_is_ready() and self.ws == None:
            if self.module_exists("websocket"):
                from websocket import create_connection
                self.ws = create_connection("ws://127.0.0.1:{}/jerky".format(
                    self.get_cache_port("http")))
            else:
                self.tell_module_missing("websocket-client")
    def tell_module_missing(self, name):
        self.message("{} missing: do a `pip install {}` and restart vim".format(name, name))
    def get_cache_port(self, where):
        self.log("get_cache_port: in")
        f = open(self.ensime_cache + where)
        port = f.read()
        f.close()
        return port.replace("\n", "")
    def send(self, what):
        self.log("send: in")
        if self.ws == None:
            self.message("still initializing")
        else:
            self.log("send: {}".format(what))
            self.ws.send(what + "\n")
    def cursor(self):
        self.log("cursor: in")
        return self.vim.current.window.cursor
    def path(self):
        self.log("path: in")
        return self.vim.current.buffer.name
    def path_start_size(self, what, where = "range"):
        self.log("path_start_size: in")
        self.vim.command("normal e")
        e = self.cursor()[1]
        self.vim.command("normal b")
        b = self.cursor()[1]
        s = e - b
        self.send_at_point(what, self.path(), self.cursor()[0], b + 1, s, where)
    def get_position(self, row, col):
        result = col -1
        f = open(self.path())
        result += sum([len(f.readline()) for i in range(row - 1)])
        f.close()
        return result
    def complete(self):
        self.log("complete: in")
        content = self.vim.eval('join(getline(1, "$"), "\n")')
        pos = self.get_position(self.cursor()[0], self.cursor()[1] + 1)
        self.send_request({"point": pos, "maxResults":100,
            "typehint":"CompletionsReq",
            "caseSens":True,
            "fileInfo": {"file": self.path(), "contents": content},
            "reload":False})
    def send_at_point(self, what, path, row, col, size, where = "range"):
        i = self.get_position(row, col)
        self.send_request({"typehint" : what + "AtPointReq",
            "file" : path,
            where : {"from": i,"to": i + size}})
    def do_no_teardown(self, args, range = None):
        self.log("do_no_teardown: in")
        self.no_teardown = True
    def type_check_cmd(self, args, range = None):
        self.log("type_check_cmd: in")
        self.type_check("")
    def type(self, args, range = None):
        self.log("type: in")
        self.path_start_size("Type")
    def ensime_is_ready(self):
        self.log("ready: in")
        return os.path.exists(self.ensime_cache + "http")
    def symbol_at_point_req(self, open_definition):
        self.open_definition = open_definition
        pos = self.get_position(self.cursor()[0], self.cursor()[1] + 1)
        self.send_request({
            "point": pos, "typehint":"SymbolAtPointReq", "file":self.path()})
    def open_declaration(self, args, range = None):
        self.log("open_declaration: in")
        self.symbol_at_point_req(True)
    def symbol(self, args, range = None):
        self.log("symbol: in")
        self.symbol_at_point_req(True)
    def doc_uri(self, args, range = None):
        self.log("doc_uri: in")
        self.path_start_size("DocUri", "point")
    def doc_browse(self, args, range = None) :
        self.log("browse: in")
        self.browse = True
        self.doc_uri(args, range = None)
    def read_line(self, s):
        self.log("read_line: in")
        ret = ''
        while True:
            c = s.recv(1)
            if c == '\n' or c == '':
                break
            else:
                ret += c
        return ret
    def message(self, m):
        self.log("message: in")
        self.vim.command("echo '{}'".format(m))
    def handle_new_scala_notes_event(self, notes):
        for note in notes:
            l = note["line"]
            c = note["col"] - 1
            e = note["col"] + (note["end"] - note["beg"])
            self.errors.append(Error(note["msg"], l, c, e))
            self.matches.append(self.vim.eval(
                "matchadd(g:EnErrorStyle, '\\%{}l\\%>{}c\\%<{}c')".format(l, c, e)))
            self.message(note["msg"])
    def handle_string_response(self, payload):
        url = "http://127.0.0.1:{}/{}".format(self.get_cache_port("http"),
                payload["text"])
        if self.browse:
            subprocess.Popen([os.environ.get("BROWSER"), url])
            self.browse = False
        self.message(url)
    def handle_completion_info_list(self, completions):
        self.suggests = [completion["name"] for completion in completions]
    def handle_payload(self, payload):
        self.log("handle_payload: in")
        typehint = payload["typehint"]
        if typehint == "SymbolInfo":
            self.message(payload["declPos"]["file"])
            if self.open_definition:
                self.vim.command(":vsplit {}".format(
                    payload["declPos"]["file"]))
        elif typehint == "IndexerReadyEvent":
            self.message("ensime indexer ready")
        elif typehint == "AnalyzerReadyEvent":
            self.message("ensime analyzer ready")
        elif typehint == "NewScalaNotesEvent":
            self.handle_new_scala_notes_event(payload["notes"])
        elif typehint == "BasicTypeInfo":
            self.message(payload["fullName"])
        elif typehint == "StringResponse":
            self.handle_string_response(payload)
        elif typehint == "CompletionInfoList":
            self.handle_completion_info_list(payload["completions"])
    def send_request(self, request):
        self.log("send_request: in")
        self.send(json.dumps({"callId" : self.callId,"req" : request}))
        self.callId += 1
    def type_check(self, filename):
        self.log("type_check: in")
        self.send_request({"typehint": "TypecheckFilesReq",
            "files" : [self.path()]})
        for i in self.matches:
            self.vim.eval("matchdelete({})".format(i))
        self.matches = []
        self.errors = []
    def on_cursor_hold(self, filename):
        self.log("on_cursor_hold: in")
        self.unqueue(filename)
        self.vim.command('call feedkeys("f\e")')
    def cursor_moved(self, filename):
        self.setup()
        if self.ws == None: return
        self.display_error_if_necessary(filename)
        self.unqueue(filename)
    def get_error_at(self, cursor):
        for error in self.errors:
            if error.includes(cursor):
                return error
        return None
    def display_error_if_necessary(self, filename):
        error = self.get_error_at(self.cursor())
        if error != None:
            self.message(error.message)
    def unqueue(self, filename):
        self.log("unqueue: in")
        while True:
            if self.queue.empty():
                break
            result = self.queue.get(False)
            self.log("unqueue: result received {}".format(str(result)))
            if result == None or result == "nil":
                self.log("unqueue: nil or None received")
                break
            _json = json.loads(result)
            if _json["payload"] != None:
                self.handle_payload(_json["payload"])
        self.log("unqueue: before close")
        self.log("unqueue: after close")
    def autocmd_handler(self, filename):
        self._increment_calls()
        self.vim.current.line = (
            'Autocmd: Called %s times, file: %s' % (self.calls, filename))
    def complete_func(self, args):
        if args[0] == '1':
            self.complete()
            line = self.vim.eval("getline('.')")
            start = self.cursor()[1] - 1
            pattern = re.compile('\a')
            while start > 0 and pattern.match(line[start - 1]):
                start -= 1
            return start
        else:
            while True:
                if self.suggests != None:
                    break
                self.unqueue("")
            result = []
            pattern = re.compile('^' + args[1])
            for m in self.suggests:
                if pattern.match(m):
                    result.append(m)
            self.suggests = None
            return result
ensime_plugin = Ensime(vim)
