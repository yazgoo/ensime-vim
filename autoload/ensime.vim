if !has('nvim')
    execute 'pyfile' expand('<sfile>:p').'.py'
endif

function! ensime#client_keys() abort
    return s:call_plugin('client_keys', [])
endfunction

function! ensime#client_status(config_path, create) abort
    return s:call_plugin('client_status', [a:config_path, a:create])
endfunction

function! ensime#teardown() abort
    return s:call_plugin('teardown', [])
endfunction

function! ensime#current_client(create, quiet, allow_classpath_file_creation) abort
    return s:call_plugin('current_client', [a:create, a:quiet, a:allow_classpath_file_creation])
endfunction

function! ensime#client_for(config_path, create, quiet, allow_classpath_file_creation) abort
    return s:call_plugin('client_for', [a:config_path, a:create, a:quiet, a:allow_classpath_file_creation])
endfunction

function! ensime#find_config_path(path) abort
    return s:call_plugin('find_config_path', [a:path])
endfunction

function! ensime#with_current_client(proc, create, quiet, allow_classpath_file_creation) abort
    return s:call_plugin('with_current_client', [a:proc, a:create, a:quiet, a:allow_classpath_file_creation])
endfunction

function! ensime#is_scala_file() abort
    return s:call_plugin('is_scala_file', [])
endfunction

function! ensime#on_receive(name, callback) abort
    return s:call_plugin('on_receive', [a:name, a:callback])
endfunction

function! ensime#send_request(request) abort
    return s:call_plugin('send_request', [a:request])
endfunction

function! ensime#fun_en_complete_func(findstart, base) abort
    return s:call_plugin('fun_en_complete_func', [a:findstart, a:base])
endfunction

function! ensime#au_vimleave(filename) abort
    return s:call_plugin('au_vimleave', [a:filename])
endfunction

function! ensime#au_buf_enter(filename) abort
    return s:call_plugin('au_buf_enter', [a:filename])
endfunction

function! ensime#au_buf_leave(filename) abort
    return s:call_plugin('au_buf_leave', [a:filename])
endfunction

function! ensime#au_buf_write_post(filename) abort
    return s:call_plugin('au_buf_write_post', [a:filename])
endfunction

function! ensime#au_cursor_hold(filename) abort
    return s:call_plugin('au_cursor_hold', [a:filename])
endfunction

function! ensime#au_cursor_moved(filename) abort
    return s:call_plugin('au_cursor_moved', [a:filename])
endfunction

function! ensime#com_en_no_teardown(args, range) abort
    return s:call_plugin('com_en_no_teardown', [a:args, a:range])
endfunction

function! ensime#com_en_type_check(args, range) abort
    return s:call_plugin('com_en_type_check', [a:args, a:range])
endfunction

function! ensime#com_en_type(args, range) abort
    return s:call_plugin('com_en_type', [a:args, a:range])
endfunction

function! ensime#com_en_format_source(args, range) abort
    return s:call_plugin('com_en_format_source', [a:args, a:range])
endfunction

function! ensime#com_en_declaration(args, range) abort
    return s:call_plugin('com_en_declaration', [a:args, a:range])
endfunction

function! ensime#com_en_declaration_split(args, range) abort
    return s:call_plugin('com_en_declaration_split', [a:args, a:range])
endfunction

function! ensime#com_en_symbol(args, range) abort
    return s:call_plugin('com_en_symbol', [a:args, a:range])
endfunction

function! ensime#com_en_inspect_type(args, range) abort
    return s:call_plugin('com_en_inspect_type', [a:args, a:range])
endfunction

function! ensime#com_en_doc_uri(args, range) abort
    return s:call_plugin('com_en_doc_uri', [a:args, a:range])
endfunction

function! ensime#com_en_doc_browse(args, range) abort
    return s:call_plugin('com_en_doc_browse', [a:args, a:range])
endfunction

function! ensime#com_en_suggest_import(args, range) abort
    return s:call_plugin('com_en_suggest_import', [a:args, a:range])
endfunction

function! ensime#com_en_set_break(args, range) abort
    return s:call_plugin('com_en_set_break', [a:args, a:range])
endfunction

function! ensime#com_en_clear_breaks(args, range) abort
    return s:call_plugin('com_en_clear_breaks', [a:args, a:range])
endfunction

function! ensime#com_en_debug_start(args, range) abort
    return s:call_plugin('com_en_debug_start', [a:args, a:range])
endfunction

function! ensime#com_en_classpath(args, range) abort
    return s:call_plugin('com_en_classpath', [a:args, a:range])
endfunction

function! ensime#com_en_debug_continue(args, range) abort
    return s:call_plugin('com_en_debug_continue', [a:args, a:range])
endfunction

function! ensime#com_en_backtrace(args, range) abort
    return s:call_plugin('com_en_backtrace', [a:args, a:range])
endfunction

function! ensime#com_en_refactor(args, range) abort
    return s:call_plugin('com_en_refactor', [a:args, a:range])
endfunction

function! ensime#com_en_clients(args, range) abort
    return s:call_plugin('com_en_clients', [a:args, a:range])
endfunction

function! s:call_plugin(method_name, args) abort
    " TODO: support nvim rpc
    if has('nvim')
      throw 'Call rplugin from vimscript: not supported yet'
    endif
    unlet! g:__error
    python <<PY
try:
  r = getattr(ensime_plugin, vim.eval('a:method_name'))(*vim.eval('a:args'))
  vim.command('let g:__result = ' + json.dumps(([] if r == None else r)))
except:
  vim.command('let g:__error = ' + json.dumps(str(sys.exc_info()[0]) + ':' + str(sys.exc_info()[1])))
PY
    if exists('g:__error')
      throw g:__error
    endif
    let res = g:__result
    unlet g:__result
    return res
endfunction
