import unittest, sys, os
sys.path.insert(0, os.path.dirname(__file__) + '/../rplugin/python')
from ensime import Ensime
from mock import MagicMock
class TestVimBuffer:
    def name(self):
        "blah" 
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
class TestEnsime(unittest.TestCase):
    def setUp(self):
        vim = TestVim()
        self.vim = vim
        vim.command = MagicMock()
        self.ensime = Ensime(vim)
    def test_init(self):
        self.vim.command.assert_called_once_with("highlight EnError ctermbg=red")
    def test_get_cache_port(self):
        with self.assertRaises(IOError):
            self.ensime.get_cache_port("42")
    def test_get_socket(self):
        assert(self.ensime.get_socket() == None)
    def test_path_start_size(self):
        self.vim.command = MagicMock()
        self.ensime.path_start_size("blah")
        assert(self.vim.command.call_args_list == [(('normal e',), {}), (('normal b',), {})])
if __name__ == '__main__':
    unittest.main()
