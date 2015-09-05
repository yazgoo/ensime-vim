python <<EOF
import vim
import json
import socket
import os
import subprocess
import re
import base64
import logging
import time
import thread
import inspect
from socket import error as socket_error
from collections import defaultdict
from websocket import create_connection
import signal
import Queue
class EnsimeLauncher:
    def __init__(self, conf_path):
        self.conf_path = conf_path
        self.version = "0.9.10-SNAPSHOT"
        if os.path.exists(self.conf_path):
            self.conf = self.parse_conf()
    def parse_conf(self):
        conf = self.read_file(self.conf_path).replace("\n", "").replace(
                "(", " ").replace(")", " ").replace('"', "").split(" :")
        pattern = re.compile("([^ ]*) *(.*)$")
        conf = [(m[0], m[1])for m in [pattern.match(x).groups() for x in conf]]
        result = {}
        for item in conf:
            result[item[0]] = item[1]
        return result
    def get_classpath(self):
        log = None
        classpath = None
        dir = "/tmp/classpath_project_ensime"
        classpath_file = "{}/classpath".format(dir)
        if not os.path.exists(classpath_file):
            if not os.path.exists(dir): os.mkdir(dir)
            build_sbt = """
import sbt._
import IO._
import java.io._
scalaVersion := "%(scala_version)"
ivyScala := ivyScala.value map { _.copy(overrideScalaVersion = true) }
// allows local builds of scala
resolvers += Resolver.mavenLocal
resolvers += Resolver.sonatypeRepo("snapshots")
resolvers += "Typesafe repository" at "http://repo.typesafe.com/typesafe/releases/"
resolvers += "Akka Repo" at "http://repo.akka.io/repository"
libraryDependencies ++= Seq(
  "org.ensime" %% "ensime" % "%(version)",
  "org.scala-lang" % "scala-compiler" % scalaVersion.value force(),
  "org.scala-lang" % "scala-reflect" % scalaVersion.value force(),
  "org.scala-lang" % "scalap" % scalaVersion.value force()
)
val saveClasspathTask = TaskKey[Unit]("saveClasspath", "Save the classpath to a file")
saveClasspathTask := {
  val managed = (managedClasspath in Runtime).value.map(_.data.getAbsolutePath)
  val unmanaged = (unmanagedClasspath in Runtime).value.map(_.data.getAbsolutePath)
  val out = file("%(classpath_file)")
  write(out, (unmanaged ++ managed).mkString(File.pathSeparator))
}"""
            replace = {"scala_version": self.conf['scala-version'], "version": self.version, "classpath_file": classpath_file}
            for k in replace.keys():
                build_sbt = build_sbt.replace("%("+k+")", replace[k])
            project_dir = "{}/project".format(dir)
            if not os.path.exists(project_dir): os.mkdir(project_dir)
            self.write_file("{}/build.sbt".format(dir), build_sbt)
            self.write_file("{}/project/build.properties".format(dir),
                    "sbt.version=0.13.8")
            cwd = os.getcwd()
            os.chdir(dir)
            log = subprocess.Popen(["sbt", "saveClasspath"], stdout=subprocess.PIPE).communicate()[0]
            os.chdir(cwd)
        classpath = self.read_file(classpath_file)
        return "{}:{}/lib/tools.jar".format(classpath, self.conf['java-home'])
    def read_file(self, path):
        f = open(path)
        result = f.read()
        f.close()
        return result
    def write_file(self, path, contents):
        f = open(path, "w")
        result = f.write(contents)
        f.close()
        return result
    def is_running(self):
        port_path = self.conf_path + "_cache/http"
        if not os.path.exists(port_path):
            return False
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect("127.0.0.1", int(self.read_file(port_path))).close()
        except:
            return False
        return True
    def run(self):
        if self.conf == None:
            print("no {} file found".format(self.conf_path))
        if self.is_running():
            print("ensime is already running")
        else:
            if not os.path.exists(self.conf['cache-dir']):
                os.mkdir(self.conf['cache-dir'])
            self.log_file = open(self.conf_path + '_cache/server.log', 'w')
            args = [a for a in [self.conf['java-home'] + "/bin/java"] +                     self.conf['java-flags'].split(" ") if a != ""] + [
                            "-cp",  self.get_classpath(),
                            "-Densime.config=" + self.conf_path,
                            "org.ensime.server.Server"]
            self.process = subprocess.Popen(args, stdout=self.log_file,
                    stderr=subprocess.STDOUT)
            self.write_file(self.conf_path + "_cache/server.pid",
                str(self.process.pid))
        return self
    def wait(self):
        self.process.wait()
    def stop(self):
        os.kill(self.process.pid, signal.SIGTERM)
        self.log_file.close()
class Ensime(object):
    def log(self, what):
        log_dir = "/tmp/"
        if os.path.isdir(self.ensime_cache):
            log_dir = self.ensime_cache
        f = open(log_dir + "ensime-vim.log", "a")
        f.write("{}: {}\n".format(time.strftime("%Y-%m-%d %H:%M:%S"), what))
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
        self.vim.command("highlight EnError ctermbg=red")
        self.is_setup = False
        self.suggests = None
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
        self.ensime = EnsimeLauncher(".ensime").run()
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
            self.start_ensime_launcher()
            #self.ensime_bridge("--quiet")
            self.vim.command("set completefunc=EnCompleteFunc")
            self.is_setup = True
        if self.ensime_is_ready() and self.ws == None:
            self.ws = create_connection("ws://127.0.0.1:{}/jerky".format(
                self.get_cache_port("http")))
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
            self.matches.append(self.vim.eval(
                "matchadd('EnError', '\\%{}l\\%>{}c\\%<{}c')".format(l, c, e)))
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
    def unqueue(self, filename):
        self.log("unqueue: in")
        self.setup()
        if self.ws == None: return
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
plugin = Ensime(vim)
EOF
fun! EnCompleteFunc(arg0, arg1)
python <<EOF
r = plugin.complete_func([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Enteardown(arg0, arg1)
python <<EOF
r = plugin.teardown([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Entype_check(arg0, arg1)
python <<EOF
r = plugin.type_check([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Enunqueue(arg0, arg1)
python <<EOF
r = plugin.unqueue([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Endo_no_teardown(arg0, arg1)
python <<EOF
r = plugin.do_no_teardown([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Entype_check_cmd(arg0, arg1)
python <<EOF
r = plugin.type_check_cmd([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Entype(arg0, arg1)
python <<EOF
r = plugin.type([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Enopen_declaration(arg0, arg1)
python <<EOF
r = plugin.open_declaration([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Ensymbol(arg0, arg1)
python <<EOF
r = plugin.symbol([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Endoc_uri(arg0, arg1)
python <<EOF
r = plugin.doc_uri([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
fun! Endoc_browse(arg0, arg1)
python <<EOF
r = plugin.doc_browse([vim.eval('a:arg0'), vim.eval('a:arg1')])
vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
EOF
let res = g:__result
unlet g:__result
return res
endfun
augroup Poi
    autocmd!
    autocmd VimLeave * call Enteardown('', '')
    autocmd BufWritePost * call Entype_check('', '')
    autocmd CursorMoved * call Enunqueue('', '')
augroup END
command! -nargs=0 EnNoTeardown call Endo_no_teardown('', '')
command! -nargs=0 EnTypeCheck call Entype_check_cmd('', '')
command! -nargs=0 EnType call Entype('', '')
command! -nargs=0 EnDeclaration call Enopen_declaration('', '')
command! -nargs=0 EnSymbol call Ensymbol('', '')
command! -nargs=0 EnDocUri call Endoc_uri('', '')
command! -nargs=0 EnDocBrowse call Endoc_browse('', '')
