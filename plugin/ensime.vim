if has('nvim')
  finish
endif
augroup ensime
    autocmd!
    autocmd VimLeave * call ensime#au_vimleave(expand('<afile>'))
    autocmd BufWritePost * call ensime#au_buf_write_post(expand('<afile>'))
    autocmd CursorHold * call ensime#au_cursor_hold(expand('<afile>'))
    autocmd CursorMoved * call ensime#au_cursor_moved(expand('<afile>'))
augroup END

command! -nargs=0 EnNoTeardown call ensime#com_en_no_teardown([])
command! -nargs=0 EnTypeCheck call ensime#com_en_type_check([])
command! -nargs=0 EnType call ensime#com_en_type([])
command! -nargs=0 EnDeclaration call ensime#com_en_declaration([])
command! -nargs=0 EnSymbol call ensime#com_en_symbol([])
command! -nargs=0 EnDocUri call ensime#com_en_doc_uri([])
command! -nargs=0 EnDocBrowse call ensime#com_en_doc_browse([])

function! EnCompleteFunc(args) abort
    return ensime#fun_en_complete_func(a:args)
endfunction
