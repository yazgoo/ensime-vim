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
        self.cursor = [42, 42] 
class TestVimCurrent:
    def __init__(self):
        self.window = TestVimWindow()
        self.buffer = TestVimBuffer()
class TestVim:
    def __init__(self):
        self.current = TestVimCurrent()
    def command(self):
        print("nothing")
    def eval(self, what):
        return "/tmp"
class TestEnsime(unittest.TestCase):
    def setUp(self):
        vim = TestVim()
        self.vim = vim
        vim.command = MagicMock()
        self.ensime = Ensime(vim)
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
        class FakeProcess:
          def __init__(self):
            self.pid = 1
          def poll(self):
            None
        process = ensime_launcher.EnsimeProcess("/tmp/", FakeProcess(), "/tmp/log", None)
        assert(process.is_running())
        assert(not process.is_ready())
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
        ensime_launcher.Util.write_file(conf_path, "blah 42")
        conf = launcher.parse_conf(conf_path)
        assert(conf['blah'] == '42')
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
