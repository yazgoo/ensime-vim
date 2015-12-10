if has('nvim')
  finish
endif
augroup ensime
    autocmd!
    autocmd VimLeave *.scala call ensime#au_vimleave(expand("<afile>"))
    autocmd BufEnter *.scala call ensime#au_buf_enter(expand("<afile>"))
    autocmd BufLeave *.scala call ensime#au_buf_leave(expand("<afile>"))
    autocmd BufWritePost *.scala call ensime#au_buf_write_post(expand("<afile>"))
    autocmd CursorHold *.scala call ensime#au_cursor_hold(expand("<afile>"))
    autocmd CursorMoved *.scala call ensime#au_cursor_moved(expand("<afile>"))
augroup END

command! -nargs=* -range EnNoTeardown call ensime#com_en_no_teardown([<f-args>], '')
command! -nargs=* -range EnTypeCheck call ensime#com_en_type_check([<f-args>], '')
command! -nargs=* -range EnType call ensime#com_en_type([<f-args>], '')
command! -nargs=* -range EnFormatSource call ensime#com_en_format_source([<f-args>], '')
command! -nargs=* -range EnDeclaration call ensime#com_en_declaration([<f-args>], '')
command! -nargs=* -range EnDeclarationSplit call ensime#com_en_declaration_split([<f-args>], '')
command! -nargs=* -range EnSymbol call ensime#com_en_symbol([<f-args>], '')
command! -nargs=* -range EnInspectType call ensime#com_en_inspect_type([<f-args>], '')
command! -nargs=* -range EnDocUri call ensime#com_en_doc_uri([<f-args>], '')
command! -nargs=* -range EnDocBrowse call ensime#com_en_doc_browse([<f-args>], '')
command! -nargs=* -range EnSuggestImport call ensime#com_en_suggest_import([<f-args>], '')
command! -nargs=* -range EnSetBreak call ensime#com_en_set_break([<f-args>], '')
command! -nargs=* -range EnClearBreaks call ensime#com_en_clear_breaks([<f-args>], '')
command! -nargs=* -range EnDebug call ensime#com_en_debug_start([<f-args>], '')
command! -nargs=* -range EnClasspath call ensime#com_en_classpath([<f-args>], '')
command! -nargs=* -range EnContinue call ensime#com_en_debug_continue([<f-args>], '')
command! -nargs=* -range EnBacktrace call ensime#com_en_backtrace([<f-args>], '')
command! -nargs=* -range EnRefactor call ensime#com_en_refactor([<f-args>], '')
command! -nargs=0 -range EnClients call ensime#com_en_clients([<f-args>], '')

function! EnCompleteFunc(a, b) abort
    return ensime#fun_en_complete_func(a:a, a:b)
endfunction
