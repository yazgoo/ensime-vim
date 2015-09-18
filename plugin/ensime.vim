if has('nvim')
  finish
endif
augroup ensime
    autocmd!
    autocmd VimLeave * call ensime#teardown(expand('<afile>'))
    autocmd BufWritePost * call ensime#type_check(expand('<afile>'))
    autocmd CursorHold * call ensime#on_cursor_hold(expand('<afile>'))
    autocmd CursorMoved * call ensime#cursor_moved(expand('<afile>'))
augroup END

command! -nargs=0 EnNoTeardown call ensime#do_no_teardown([])
command! -nargs=0 EnTypeCheck call ensime#type_check_cmd([])
command! -nargs=0 EnType call ensime#type([])
command! -nargs=0 EnDeclaration call ensime#open_declaration([])
command! -nargs=0 EnSymbol call ensime#symbol([])
command! -nargs=0 EnDocUri call ensime#doc_uri([])
command! -nargs=0 EnDocBrowse call ensime#doc_browse([])

function! EnCompleteFunc(args) abort
    return ensime#complete_func(a:args)
endfunction
