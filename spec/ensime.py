import unittest, sys, os
def fakemodule_autocmd(arg):
    return(arg)
class fakemodule(object):
    @staticmethod
    def plugin(arg):
        return(arg)
    @staticmethod
    def autocmd(arg, **kwargs):
        return fakemodule_autocmd
    @staticmethod
    def command(arg, **kwargs):
        return fakemodule_autocmd
    @staticmethod
    def function(arg, **kwargs):
        return fakemodule_autocmd
import sys
sys.modules["neovim"] = fakemodule
sys.path.insert(0, os.path.dirname(__file__) + '/../rplugin/python')
from ensime import Ensime
import ensime_launcher
from mock import MagicMock
class TestVimBuffer:
    def __init__(self):
        self.name =  __file__
class TestVimWindow:
    def __init__(self):
        self.cursor = [0, 0] 
class TestVimCurrent:
    def __init__(self):
        self.window = TestVimWindow()
        self.buffer = TestVimBuffer()
class TestVim:
    def __init__(self):
        self.current = TestVimCurrent()
    def command(self, what):
        return None
    def eval(self, what):
        return "/tmp"
class TestEnsime(unittest.TestCase):
    def setUp(self):
        vim = TestVim()
        self.vim = vim
        vim.command = MagicMock()
        self.ensime = Ensime(vim)
        self.poll = None
    def test_util(self):
        path = "/tmp/my/little/dir"
        test_file = path + "/test"
        if(os.path.exists(test_file)): os.remove(test_file)
        if(os.path.exists(path)): os.rmdir(path)
        ensime_launcher.Util.mkdir_p(path);
        assert(os.path.exists(path))
        if os.path.exists(test_file): os.remove(test_file)
        ensime_launcher.Util.write_file(test_file, "blah")
        assert(os.path.exists(test_file))
        os.remove(test_file)
        os.rmdir(path)
    def test_ensime_process(self):
        a = self
        class FakeProcess:
            def __init__(self):
                self.pid = 1
            def poll(self):
                return a.poll
        process = ensime_launcher.EnsimeProcess(
                "/tmp/", FakeProcess(), "/tmp/log", None)
        assert(process.is_running())
        self.poll = True
        assert(not process.is_ready())
        self.poll = None
        assert(not process.is_ready())
        import socket
        old_socket = socket.socket
        class FakeSocket:
            def connect(self, a):
                None
            def close(self):
                None
        def new_socket(a, b):
            return FakeSocket()
        socket.socket = new_socket
        ensime_launcher.Util.write_file("/tmp/http", "42")
        print(process.is_ready())
        socket.socket = old_socket
        assert(not process.aborted())
        stop_exception = False
        try:
            process.stop()
        except:
            stop_exception = True
        assert(stop_exception)
    def test_ensime_launcher(self):
        launcher = ensime_launcher.EnsimeLauncher(TestVim())
        conf_path = "/tmp/myconf"
        ensime_launcher.Util.write_file(conf_path, "blah 42 :scala-version test :java-home /usr :cache-dir /tmp :java-flags none")
        conf = launcher.parse_conf(conf_path)
        assert(conf['blah'] == '42')
        test_dir = "/tmp/classpath_project_ensime/test"
        ensime_launcher.Util.mkdir_p(test_dir);
        assert(launcher.classpath_project_dir("test") == test_dir)
        assert(launcher.build_sbt("test", "file") != None)
        ensime_launcher.Util.write_file(test_dir + "/classpath", "")
        launcher.launch(conf_path)
        launcher.generate_classpath("test", "classpath")
    def test_ensime_init_path(self):
        from ensime import EnsimeInitPath
        assert(EnsimeInitPath() == None)
        original_abspath = os.path.abspath
        def new_abspath(path):
            return '/autoload/ensime.vim.py'
        os.path.abspath = new_abspath
        assert(EnsimeInitPath() == None)
        os.path.abspath = original_abspath
    def test_error(self):
        from ensime import Error
        error = Error("message", 1, 2, 4)
        assert(error.includes([1, 3]))
    def test_ensime_client(self):
        self.test_ensime_launcher()
        from ensime import EnsimeClient
        launcher = ensime_launcher.EnsimeLauncher(TestVim())
        client = EnsimeClient(TestVim(), launcher, "spec/conf")
        assert(not client.module_exists("unexisting_module"))
        assert(client.module_exists("os"))
        client.teardown("/tmp/")
        assert(client.path_start_size("/tmp") == None)
        assert(client.unqueue("/tmp") == None)
        client.queue.put(None)
        assert(client.unqueue("/tmp") == None)
        client.queue.put('{"payload":{"typehint":"blah"}}')
        assert(client.unqueue("/tmp") == None)
        client.setup()
        assert(client.complete() == None)
        notes = [{"line":0, "col":0, "beg":0, "end":1, "msg":"msg"}]
        client.handle_new_scala_notes_event(notes)
        [client.handle_payload({"typehint":typehint, "notes":notes, "declPos": { "file": "none" }, "fullName": "none", "text": "none", "completions":[] }) 
                for typehint in ["NewScalaNotesEvent", "SymbolInfo", "IndexerReadyEvent", "AnalyzerReadyEvent", "BasicTypeInfo", "StringResponse", "CompletionInfoList"]]
        assert(client.get_cache_port("http") == "42")
        class FakeSocket:
            def __init__(self):
                self.first = True
            def recv(self, n):
                if self.first:
                    self.first = False
                    return 'n'
                else:
                    return ''

        client.read_line(FakeSocket())
        assert(client.complete_func('1', "") == 0)
        client.suggests = []
        assert(client.complete_func(0, "") == [])
        client.handle_string_response({"text": "lol"})
        client.browse = True
        old_get = os.environ.get
        def new_get(blah):
            return "echo"
        os.environ.get = new_get
        client.handle_string_response({"text": "lol"})
        os.environ.get = old_get
        assert(client.type_check("/tmp") == None)
        assert(client.on_cursor_hold("/tmp") == None)
        assert(client.cursor_moved("/tmp") == None)
        assert(client.get_error_at([0, 0]) == None)
        from ensime import Error
        error = Error("a", 0, 0, 10)
        client.errors.append(error)
        assert(client.get_error_at([0, 0]) == error)
        assert(client.display_error_if_necessary("/tmp") == None)
        client.tell_module_missing("module")
        assert(client.doc_browse(None) == None)
        assert(client.type_check_cmd([]) == None)
        assert(client.type([]) == None)
        assert(client.symbol_at_point_req(None) == None)
        assert(client.symbol(None) == None)
        assert(client.open_declaration(None) == None)
        assert(client.do_no_teardown(None) == None)
        client.ws = True
        assert(client.cursor_moved("") == None)
        class FakeWS:
            def recv(self):
                return ""
            def send(self, blah):
                None
        client.ws = FakeWS()
        client.x = 0
        def once():
            client.x = client.x + 1
            return client.x <= 1
        assert(client.unqueue_poll(once, 0) == None)
        assert(client.send("blah") == None)
    def test_ensime(self):
        self.test_ensime_launcher()
        assert(self.ensime.client_status("spec/conf", False) == "unloaded")
        assert(self.ensime.client_status("spec/conf") == "startup")
        assert(self.ensime.find_config_path("/tmp/") == None)
        assert(self.ensime.current_client() == None)
        assert(len(self.ensime.client_keys()) == 1)
        assert(self.ensime.with_current_client(lambda c: None) == None)
        assert(self.ensime.teardown() == None)
        for com in ["en_no_teardown", "en_type_check", "en_type", "en_declaration", "en_doc_uri", "en_doc_browse", "en_clients"]:
            assert(getattr(self.ensime, 'com_' + com)([]) == None)
        for au in ["buf_write_post", "cursor_hold", "cursor_moved"]:
            assert(getattr(self.ensime, 'au_' + au)("") == None)
        assert(self.ensime.fun_en_complete_func(["a", "b"]) == None)


#    def test_init(self):
#        self.vim.command.assert_called_once_with("highlight EnError ctermbg=red")
#    def test_get_cache_port(self):
#        with self.assertRaises(IOError):
#            self.ensime.current_client().get_cache_port("42")
#    def test_path_start_size(self):
#        self.vim.command = MagicMock()
#        self.ensime.current_client().path_start_size("blah")
#        assert((('normal e',), {}) in self.vim.command.call_args_list)
#        assert((('normal b',), {}) in self.vim.command.call_args_list)

if __name__ == '__main__':
    unittest.main()
