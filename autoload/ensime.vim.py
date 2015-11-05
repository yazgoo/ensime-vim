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

import ensime_launcher
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
    def __init__(self, path, message, l, c, e):
        self.path = os.path.abspath(path)
        self.message = message
        self.l = l
        self.c = c
        self.e = e
    def includes(self, path, cursor):
        return self.path == os.path.abspath(path) and cursor[0] == self.l and self.c <= cursor[1] and cursor[1] < self.e

class EnsimeClient(object):
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
        f = open(log_dir + "/ensime-vim.log", "a")
        f.write("{}: {}\n".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f"), what))
        f.close()
    def unqueue_poll(self, running = lambda: True, sleep_t = 1):
        while running():
            if self.ws != None:
                result = self.ws.recv()
                self.queue.put(result)
            time.sleep(sleep_t)
    def on_receive(self, name, callback):
        self.log("on_receive: {}".format(callback))
        self.receive_callbacks[name] = callback
    def __init__(self, vim, launcher, config_path):
        self.config_path = os.path.abspath(config_path)
        self.ensime_cache = os.path.join(os.path.dirname(self.config_path), ".ensime_cache")
        self.launcher = launcher
        self.log("__init__: in")
        self.call_id = 0
        self.browse = False
        self.vim = vim
        self.receive_callbacks = {}
        self.matches = []
        self.errors = []
        self.vim.command("highlight EnError ctermbg=red gui=underline")
        self.vim.command("let g:EnErrorStyle='EnError'")
        self.suggests = None
        self.ensime = None
        self.no_teardown = False
        self.open_definition = False
        self.en_format_source_id = None
        self.debug_thread_id = None
        self.ws = None
        self.queue = Queue.Queue()
        self.complete_timeout = 20
        thread.start_new_thread(self.unqueue_poll, ())
    def teardown(self, filename):
        self.log("teardown: in")
        if self.ensime != None and not self.no_teardown:
            self.ensime.stop()
    def setup(self):
        if self.ensime == None:
            self.log("starting up ensime")
            self.message("ensime startup")
            self.ensime = self.launcher.launch(self.config_path)
            self.vim.command("set omnifunc=EnCompleteFunc")
        if self.ws == None and self.ensime.is_ready():
            if self.module_exists("websocket"):
                from websocket import create_connection
                self.ws = create_connection("ws://127.0.0.1:{}/jerky".format(
                    self.ensime.http_port()))
            else:
                self.tell_module_missing("websocket-client")
    def tell_module_missing(self, name):
        self.message("{} missing: do a `pip install {}` and restart vim".format(name, name))
    def send(self, what):
        self.log("send: in")
        if self.ws == None:
            self.message("still initializing")
        else:
            try:
                self.log("send: {}".format(what))
                self.ws.send(what + "\n")
            except Exception as e:
                self.log("send error: {}, reconnecting...".format(e))
                from websocket import create_connection
                self.ws = create_connection("ws://127.0.0.1:{}/jerky".format(
                    self.ensime.http_port()))
                self.ws.send(what + "\n")

    def cursor(self):
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
    def get_file_info(self):
        content = self.vim.eval('join(getline(1, "$"), "\n")')
        return {"file": self.path(), "contents": content}
    def complete(self):
        self.log("complete: in")
        pos = self.get_position(self.cursor()[0], self.cursor()[1] + 1)
        self.send_request({"point": pos, "maxResults":100,
            "typehint":"CompletionsReq",
            "caseSens":True,
            "fileInfo": self.get_file_info(),
            "reload":False})
    def send_at_point(self, what, path, row, col, size, where = "range"):
        i = self.get_position(row, col)
        self.send_request({"typehint" : what + "AtPointReq",
            "file" : path,
            where : {"from": i,"to": i + size}})
    # @neovim.command('EnNoTeardown', range='', nargs='*', sync=True)
    def do_no_teardown(self, args, range = None):
        self.log("do_no_teardown: in")
        self.no_teardown = True
    # @neovim.command('EnTypeCheck', range='', nargs='*', sync=True)
    def type_check_cmd(self, args, range = None):
        self.log("type_check_cmd: in")
        self.type_check("")
    # @neovim.command('EnFormatSource', range='', nargs='*', sync=True)
    def format_source(self, args, range = None):
        self.log("type_check_cmd: in")
        self.en_format_source_id = self.send_request({"typehint": "FormatOneSourceReq", "file": self.get_file_info()})
    # @neovim.command('EnType', range='', nargs='*', sync=True)
    def type(self, args, range = None):
        self.log("type: in")
        self.path_start_size("Type")
    def symbol_at_point_req(self, open_definition):
        self.open_definition = open_definition
        pos = self.get_position(self.cursor()[0], self.cursor()[1])
        self.send_request({
            "point": pos, "typehint":"SymbolAtPointReq", "file":self.path()})
    # @neovim.command('EnDeclaration', range='', nargs='*', sync=True)
    def open_declaration(self, args, range = None):
        self.log("open_declaration: in")
        self.symbol_at_point_req(True)
    # @neovim.command('EnSymbol', range='', nargs='*', sync=True)
    def symbol(self, args, range = None):
        self.log("symbol: in")
        self.symbol_at_point_req(False)
    # @neovim.command('EnSuggestImport', range='', nargs='*', sync=True)
    def suggest_import(self, args, range = None):
        self.log("inspect_type: in")
        pos = self.get_position(self.cursor()[0], self.cursor()[1])
        self.send_request({"point": pos, "maxResults":10, "names": ["CacheBuilder"], "typehint": "ImportSuggestionsReq", "file": self.path()})
    # @neovim.command('EnSetBreak', range='', nargs='*', sync=True)
    def set_break(self, args, range = None):
        self.log("set_break: in")
        self.send_request({"line": self.cursor()[0], "maxResults":10, "typehint": "DebugSetBreakReq", "file": self.path()})
    # @neovim.command('EnClearBreaks', range='', nargs='*', sync=True)
    def clear_breaks(self, args, range = None):
        self.log("clear_breaks: in")
        self.send_request({"typehint": "DebugClearAllBreakReq"})
    # @neovim.command('EnDebug', range='', nargs='*', sync=True)
    def debug_start(self, args, range = None):
        self.log("debug_start: in")
        self.send_request({"typehint": "DebugStartReq", "commandLine": args[0]})
    # @neovim.command('EnContinue', range='', nargs='*', sync=True)
    def debug_continue(self, args, range = None):
        self.log("debug_start: in")
        self.send_request({"typehint": "DebugContinueReq", "threadId": self.debug_thread_id})
    # @neovim.command('EnContinue', range='', nargs='*', sync=True)
    def backtrace(self, args, range = None):
        self.log("backtrace: in")
        self.send_request({"typehint": "DebugBacktraceReq", "threadId": self.debug_thread_id, "index":0, "count":100})
    # @neovim.command('EnInspectType', range='', nargs='*', sync=True)
    def inspect_type(self, args, range = None):
        self.log("inspect_type: in")
        pos = self.get_position(self.cursor()[0], self.cursor()[1])
        self.send_request({"point": pos, "typehint": "InspectTypeAtPointReq", "file": self.path(), "range": {"from": pos, "to": pos}})
    # @neovim.command('EnDocUri', range='', nargs='*', sync=True)
    def doc_uri(self, args, range = None):
        self.log("doc_uri: in")
        self.path_start_size("DocUri", "point")
    # @neovim.command('EnDocBrowse', range='', nargs='*', sync=True)
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
        self.log(m)
        self.vim.command("echo \"{}\"".format(m.replace('"', '\\"')))
    def handle_new_scala_notes_event(self, notes):
        for note in notes:
            l = note["line"]
            c = note["col"] - 1
            e = note["col"] + (note["end"] - note["beg"])
            if os.path.abspath(self.vim.eval("expand('%:p')")) == os.path.abspath(note["file"]):
                self.errors.append(Error(note["file"], note["msg"], l, c, e))
                match = self.vim.eval(
                    "matchadd(g:EnErrorStyle, '\\%{}l\\%>{}c\\%<{}c')".format(l, c, e))
                self.log("adding match {} at line {} column {} error {}".format(match, l, c, e))
                self.matches.append(match)
    def handle_string_response(self, payload):
        if self.en_format_source_id == None:
            url = "http://127.0.0.1:{}/{}".format(self.ensime.http_port(),
                    payload["text"])
            if self.browse:
                subprocess.Popen([os.environ.get("BROWSER"), url])
                self.browse = False
            self.message(url)
        else:
            self.vim.current.buffer[:] =  [line.encode('utf-8') for line in payload["text"].split("\n")]
            self.en_format_source_id = None
    def handle_completion_info_list(self, completions):
        self.suggests = [completion["name"] for completion in completions]
    def handle_payload(self, payload):
        self.log("handle_payload: in {}".format(payload))
        typehint = payload["typehint"]
        if typehint == "SymbolInfo":
            try:
                self.message(payload["declPos"]["file"])
                if self.open_definition:
                    self.clean_errors()
                    self.vim.command(":vsplit {}".format(
                        payload["declPos"]["file"]))
                    self.vim.command("filetype detect")
            except KeyError:
                self.message("symbol not found")
        elif typehint == "IndexerReadyEvent":
            self.message("ensime indexer ready")
        elif typehint == "AnalyzerReadyEvent":
            self.message("ensime analyzer ready")
        elif typehint == "NewScalaNotesEvent":
            self.handle_new_scala_notes_event(payload["notes"])
        elif typehint == "BasicTypeInfo":
            self.show_type(payload)
        elif typehint == "StringResponse":
            self.handle_string_response(payload)
        elif typehint == "CompletionInfoList":
            self.handle_completion_info_list(payload["completions"])
        elif typehint == "TypeInspectInfo":
            self.message(payload["type"]["fullName"])
        elif typehint == "DebugOutputEvent":
            self.message(payload["body"].encode("ascii","ignore"))
        elif typehint == "DebugBreakEvent":
            self.message("breaked at {} {}".format(payload["file"], payload["line"]))
            self.debug_thread_id = payload["threadId"]
        elif typehint == "DebugBacktrace":
            self.show_backtrace(payload["frames"])
    def show_type(self, payload):
        _type = payload["fullName"]
        if payload["typeArgs"] != []:
            _type += "["
            _type = ",".join([x["name"] for x in payload["typeArgs"]])
            _type += "]"
        self.message(_type)
    def show_backtrace(self, frames):
        self.vim.command(":split backtrace.json")
        self.vim.current.buffer[:] = json.dumps(frames, indent=2).split("\n")
    def send_request(self, request):
        self.log("send_request: in")
        self.send(json.dumps({"callId" : self.call_id,"req" : request}))
        call_id = self.call_id
        self.call_id += 1
        return call_id
    def clean_errors(self):
#        for i in self.matches:
#            self.vim.eval("matchdelete({})".format(i))
        self.vim.eval("clearmatches()")
        self.matches = []
        self.errors = []
    # @neovim.autocmd('BufLeave', pattern='*.scala', eval='expand("<afile>")', sync=True)
    def buffer_leave(self, filename):
        self.log("buffer_leave: {}".format(filename))
        self.clean_errors()
    # @neovim.autocmd('BufEnter', pattern='*.scala', eval='expand("<afile>")', sync=True)
    def buffer_enter(self, filename):
        if self.vim.eval("&mod") == '0':
            self.type_check(filename)
    # @neovim.autocmd('BufWritePost', pattern='*.scala', eval='expand("<afile>")', sync=True)
    def type_check(self, filename):
        self.log("type_check: in")
        self.send_request({"typehint": "TypecheckFilesReq",
            "files" : [self.path()]})
        self.clean_errors()
    # @neovim.autocmd('CursorHold', pattern='*.scala', eval='expand("<afile>")', sync=True)
    def on_cursor_hold(self, filename):
        self.unqueue(filename)
        # http://vim.wikia.com/wiki/Timer_to_execute_commands_periodically
        self.vim.command('set updatetime=1000')
        self.vim.command('call feedkeys("f\e")')
    # @neovim.autocmd('CursorMoved', pattern='*.scala', eval='expand("<afile>")', sync=True)
    def cursor_moved(self, filename):
        self.setup()
        if self.ws == None: return
        self.display_error_if_necessary(filename)
        self.unqueue(filename)
    def get_error_at(self, cursor):
        for error in self.errors:
            if error.includes(self.vim.eval("expand('%:p')"), cursor):
                return error
        return None
    def display_error_if_necessary(self, filename):
        error = self.get_error_at(self.cursor())
        if error != None:
            self.message(error.message)
    def unqueue(self, filename):
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
                for name in self.receive_callbacks:
                    self.log("launching callback: {}".format(name))
                    self.receive_callbacks[name](self, _json["payload"])
                self.handle_payload(_json["payload"])
    # @neovim.function('EnCompleteFunc', sync=True)
    def complete_func(self, findstart, base):
        self.log("complete_func: in {} {}".format(findstart, base))
        if findstart == '1':
            self.complete()
            line = self.vim.eval("getline('.')")
            col = self.cursor()[1]
            start = col
            pattern = re.compile(r'\b')
            while start > 0 and pattern.match(line[start - 1]):
                start -= 1
            return min(start, col)
        else:
            start = time.time()
            while (time.time() - start) < self.complete_timeout:
                if self.suggests != None:
                    break
                self.unqueue("")
            result = []
            if self.suggests != None:
                pattern = re.compile('^' + base)
                for m in self.suggests:
                    if pattern.match(m):
                        result.append(m)
                self.suggests = None
            return result

class Ensime:
    def __init__(self, vim):
        self.vim = vim
        self.clients = {} # .ensime path => ensime server process
        self.launcher = ensime_launcher.EnsimeLauncher(vim)

    def __message(self, m):
        # TODO: escape m
        self.vim.command("echo '{}'".format(m))

    def client_keys(self):
        return self.clients.keys()

    def client_status(self, config_path, create = True):
        c = self.client_for(config_path, create)
        if c == None or c.ensime == None:
            return 'unloaded'
        elif c.ensime.is_ready():
            return 'ready'
        elif c.ensime.is_running():
            return 'startup'
        elif c.ensime.aborted():
            return 'aborted'
        else:
            return 'stopped'

    def teardown(self):
        for c in self.clients.values():
            c.teardown(None)

    def current_client(self):
        config_path = self.find_config_path(self.vim.eval("expand('%:p')"))
        if config_path == None:
            return None
        else:
            return self.client_for(config_path)

    def client_for(self, config_path, create = True):
        abs_path = os.path.abspath(config_path)
        if abs_path in self.clients:
            return self.clients[abs_path]
        elif create:
            client = EnsimeClient(self.vim, self.launcher, config_path)
            self.clients[abs_path] = client
            self.__message("Starting up ensime server...")
            client.setup()
            return client
        else:
            return None

    def find_config_path(self, path):
        abs_path = os.path.abspath(path)
        config_path = os.path.join(abs_path, '.ensime')

        if abs_path == os.path.abspath('/'):
            return None
        elif os.path.isfile(config_path):
            return config_path
        else:
            return self.find_config_path(os.path.dirname(abs_path))

    def with_current_client(self, proc):
        c = self.current_client()
        if c != None:
            return proc(c)

    def is_scala_file(self):
        return self.vim.eval('&filetype') == 'scala'

    def com_en_no_teardown(self, args, range = None):
        self.with_current_client(lambda c: c.do_no_teardown(None, None))

    def com_en_type_check(self, args, range = None):
        self.with_current_client(lambda c: c.type_check_cmd(None))

    def com_en_type(self, args, range = None):
        self.with_current_client(lambda c: c.type(None))

    def com_en_format_source(self, args, range = None):
        self.with_current_client(lambda c: c.format_source(None))

    def com_en_declaration(self, args, range = None):
        self.with_current_client(lambda c: c.open_declaration(args, range))

    def com_en_symbol(self, args, range = None):
        self.with_current_client(lambda c: c.symbol(args, range))

    def com_en_inspect_type(self, args, range = None):
        self.with_current_client(lambda c: c.inspect_type(args, range))

    def com_en_doc_uri(self, args, range = None):
        self.with_current_client(lambda c: c.doc_uri(args, range))

    def com_en_doc_browse(self, args, range = None):
        self.with_current_client(lambda c: c.doc_browse(args, range))

    def com_en_suggest_import(self, args, range = None):
        self.with_current_client(lambda c: c.suggest_import(args, range))

    def com_en_set_break(self, args, range = None):
        self.with_current_client(lambda c: c.set_break(args, range))

    def com_en_clear_breaks(self, args, range = None):
        self.with_current_client(lambda c: c.clear_breaks(args, range))

    def com_en_debug_start(self, args, range = None):
        self.with_current_client(lambda c: c.debug_start(args, range))

    def com_en_debug_continue(self, args, range = None):
        self.with_current_client(lambda c: c.debug_continue(args, range))

    def com_en_backtrace(self, args, range = None):
        self.with_current_client(lambda c: c.backtrace(args, range))

    def com_en_clients(self, args, range = None):
        for path in self.client_keys():
            self.__message("{}: {}".format(path, self.client_status(path)))

    def au_vimleave(self, filename):
        self.teardown()

    def au_buf_enter(self, filename):
        self.with_current_client(lambda c: c.buffer_enter(filename))

    def au_buf_leave(self, filename):
        self.with_current_client(lambda c: c.buffer_leave(filename))

    def au_buf_write_post(self, filename):
        self.with_current_client(lambda c: c.type_check(filename))

    def au_cursor_hold(self, filename):
        self.with_current_client(lambda c: c.on_cursor_hold(filename))

    def au_cursor_moved(self, filename):
        self.with_current_client(lambda c: c.cursor_moved(filename))

    def fun_en_complete_func(self, findstart, base = None):
        if base == None:
            base = findstart[1]
            findstart = findstart[0]
        if self.is_scala_file():
            return self.with_current_client(lambda c: c.complete_func(findstart, base))
        else:
            return []
    def on_receive(self, name, callback):
        self.with_current_client(lambda c: c.on_receive(name,  callback))
    def send_request(self, request):
        self.with_current_client(lambda c: c.send_request(request))
ensime_plugin = Ensime(vim)
