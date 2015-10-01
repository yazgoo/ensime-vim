if has('nvim')
  finish
endif
augroup ensime
    autocmd!
    autocmd VimLeave *.scala call ensime#au_vimleave(expand("<afile>"))
    autocmd BufWritePost *.scala call ensime#au_buf_write_post(expand("<afile>"))
    autocmd CursorHold *.scala call ensime#au_cursor_hold(expand("<afile>"))
    autocmd CursorMoved *.scala call ensime#au_cursor_moved(expand("<afile>"))
augroup END

command! -nargs=* -range EnNoTeardown call ensime#com_en_no_teardown([<f-args>], '')
command! -nargs=* -range EnTypeCheck call ensime#com_en_type_check([<f-args>], '')
command! -nargs=* -range EnType call ensime#com_en_type([<f-args>], '')
command! -nargs=* -range EnDeclaration call ensime#com_en_declaration([<f-args>], '')
command! -nargs=* -range EnSymbol call ensime#com_en_symbol([<f-args>], '')
command! -nargs=* -range EnDocUri call ensime#com_en_doc_uri([<f-args>], '')
command! -nargs=* -range EnDocBrowse call ensime#com_en_doc_browse([<f-args>], '')
command! -nargs=0 -range EnClients call ensime#com_en_clients([<f-args>], '')

function! EnCompleteFunc(findstart, base) abort
    return ensime#fun_en_complete_func(a:findstart, a:base)
endfunction
