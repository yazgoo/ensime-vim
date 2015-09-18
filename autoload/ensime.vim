if !has('nvim')
    execute 'pyfile' expand('<sfile>:p').'.py'
endif

function! ensime#module_exists(module_name) abort
    return s:call_plugin('module_exists', [a:module_name])
endfunction

function! ensime#log(what) abort
    return s:call_plugin('log', [a:what])
endfunction

function! ensime#unqueue_poll() abort
    return s:call_plugin('unqueue_poll', [])
endfunction

function! ensime#ensime_bridge(action) abort
    return s:call_plugin('ensime_bridge', [a:action])
endfunction

function! ensime#start_ensime_launcher() abort
    return s:call_plugin('start_ensime_launcher', [])
endfunction

function! ensime#stop_ensime_launcher() abort
    return s:call_plugin('stop_ensime_launcher', [])
endfunction

function! ensime#setup() abort
    return s:call_plugin('setup', [])
endfunction

function! ensime#tell_module_missing(name) abort
    return s:call_plugin('tell_module_missing', [a:name])
endfunction

function! ensime#get_cache_port(where) abort
    return s:call_plugin('get_cache_port', [a:where])
endfunction

function! ensime#send(what) abort
    return s:call_plugin('send', [a:what])
endfunction

function! ensime#cursor() abort
    return s:call_plugin('cursor', [])
endfunction

function! ensime#path() abort
    return s:call_plugin('path', [])
endfunction

function! ensime#path_start_size(what, where) abort
    return s:call_plugin('path_start_size', [a:what, a:where])
endfunction

function! ensime#get_position(row, col) abort
    return s:call_plugin('get_position', [a:row, a:col])
endfunction

function! ensime#complete() abort
    return s:call_plugin('complete', [])
endfunction

function! ensime#send_at_point(what, path, row, col, size, where) abort
    return s:call_plugin('send_at_point', [a:what, a:path, a:row, a:col, a:size, a:where])
endfunction

function! ensime#ensime_is_ready() abort
    return s:call_plugin('ensime_is_ready', [])
endfunction

function! ensime#symbol_at_point_req(open_definition) abort
    return s:call_plugin('symbol_at_point_req', [a:open_definition])
endfunction

function! ensime#read_line(s) abort
    return s:call_plugin('read_line', [a:s])
endfunction

function! ensime#message(m) abort
    return s:call_plugin('message', [a:m])
endfunction

function! ensime#handle_new_scala_notes_event(notes) abort
    return s:call_plugin('handle_new_scala_notes_event', [a:notes])
endfunction

function! ensime#handle_string_response(payload) abort
    return s:call_plugin('handle_string_response', [a:payload])
endfunction

function! ensime#handle_completion_info_list(completions) abort
    return s:call_plugin('handle_completion_info_list', [a:completions])
endfunction

function! ensime#handle_payload(payload) abort
    return s:call_plugin('handle_payload', [a:payload])
endfunction

function! ensime#send_request(request) abort
    return s:call_plugin('send_request', [a:request])
endfunction

function! ensime#get_error_at(cursor) abort
    return s:call_plugin('get_error_at', [a:cursor])
endfunction

function! ensime#display_error_if_necessary(filename) abort
    return s:call_plugin('display_error_if_necessary', [a:filename])
endfunction

function! ensime#unqueue(filename) abort
    return s:call_plugin('unqueue', [a:filename])
endfunction

function! ensime#autocmd_handler(filename) abort
    return s:call_plugin('autocmd_handler', [a:filename])
endfunction

function! ensime#complete_func(args) abort
    return s:call_plugin('complete_func', [a:args])
endfunction

function! ensime#teardown(filename) abort
    return s:call_plugin('teardown', [a:filename])
endfunction

function! ensime#type_check(filename) abort
    return s:call_plugin('type_check', [a:filename])
endfunction

function! ensime#on_cursor_hold(filename) abort
    return s:call_plugin('on_cursor_hold', [a:filename])
endfunction

function! ensime#cursor_moved(filename) abort
    return s:call_plugin('cursor_moved', [a:filename])
endfunction

function! ensime#do_no_teardown(args, range) abort
    return s:call_plugin('do_no_teardown', [a:args, a:range])
endfunction

function! ensime#type_check_cmd(args, range) abort
    return s:call_plugin('type_check_cmd', [a:args, a:range])
endfunction

function! ensime#type(args, range) abort
    return s:call_plugin('type', [a:args, a:range])
endfunction

function! ensime#open_declaration(args, range) abort
    return s:call_plugin('open_declaration', [a:args, a:range])
endfunction

function! ensime#symbol(args, range) abort
    return s:call_plugin('symbol', [a:args, a:range])
endfunction

function! ensime#doc_uri(args, range) abort
    return s:call_plugin('doc_uri', [a:args, a:range])
endfunction

function! ensime#doc_browse(args, range) abort
    return s:call_plugin('doc_browse', [a:args, a:range])
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
