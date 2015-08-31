fun EnSetup()
    highlight EnError ctermbg=red
ruby <<EOF
    $en_matches = []
    $browse = true
EOF
endfunc
fun EnSend(what)
    ruby <<EOF
    require 'socket'
    bridge_file = ".ensime_cache/bridge"
    begin
        if File.exists? bridge_file
            s = TCPSocket.new 'localhost', File.read(bridge_file).to_i
            what = VIM::evaluate("a:what")
            s.puts what
            s.close
        end
    rescue Errno::ECONNREFUSED
        # ignore this
    end
EOF
endfun
fun EnUnqueue()
ruby <<EOF
    require 'socket'
    require 'json'
    def handle_palyoad payload
        typehint = payload["typehint"]
        if typehint == "NewScalaNotesEvent"
            notes = payload["notes"]
            notes.each do |note|
                l = note["line"]
                c = note["col"] - 1
                e = note["col"] + (note["end"] - note["beg"])
                $en_matches << VIM.evaluate("matchadd('EnError', '\\%#{l}l\\%>#{c}c\\%<#{e}c')")
            end
        elsif typehint == "StringResponse"
            url = "http://127.0.0.1:#{File.read(".ensime_cache/http").chomp}/#{payload["text"]}"
            VIM.message(url)
            if $browse
                VIM.command("!#{ENV['BROWSER']} #{url.gsub('#', '\#')}")
                $browse = false
            end
        elsif typehint == "ArrowTypeInfo"
            VIM.message(payload["name"])
        elsif typehint == "BasicTypeInfo"
            VIM.message(payload["fullName"])
        elsif typehint == "CompletionInfoList"
            array = payload["completions"].collect do |completion|
                completion["name"]
            end.to_json
            File.open("/tmp/ensime_suggests", "w") { |f| f.write array }
            VIM.command("let g:suggests = #{array}")
        end
    end
    bridge_file = ".ensime_cache/bridge"
    if File.exists? bridge_file
        begin
            s = TCPSocket.new 'localhost', File.read(bridge_file).to_i
            s.puts "unqueue"
            while true
                result = s.readline
                if result.nil? or result.chomp == "nil"
                    break
                end
                #VIM::message result
                json = JSON.parse result
                handle_palyoad json["payload"] if json["payload"]

            end
            s.close
        rescue Errno::ECONNREFUSED
            # do nothing if there is an error (e.ge
        end
    end
EOF
endfun
fun EnTypeCheck()
    call EnSend("typecheck \"".expand('%:p') ."\"")
    ruby <<EOF
    $en_matches.each { |i| VIM.evaluate("matchdelete(#{i})") }
    $en_matches.clear
EOF
endfun
fun EnPathStartSize(what)
    ruby VIM.command("normal e")
    let e = col('.')
    ruby VIM.command("normal b")
    let b = col('.')
    let s = e - b
    call EnSend(a:what." \"".expand('%:p')."\", ".line('.').", ".b.", ".s)
endfun
fun EnComplete()
    call EnSend("complete \"".expand('%:p')."\", ".line('.').", ".col('.'))
endfun
fun EnDocUri()
    call EnPathStartSize("doc_uri")
endfun
fun EnDocBrowse()
    ruby $browse = true
    call EnDocUri()
endfun
fun EnType()
    call EnPathStartSize("type")
endfun
augroup Poi
    autocmd!
    autocmd BufWritePost * call EnTypeCheck()
    autocmd CursorMoved * call EnUnqueue()
augroup END
fun! EnCompleteFunc(findstart, base) 
    if a:findstart 
        call EnComplete()
        " locate the start of the word 
        let line = getline('.') 
        let start = col('.') - 1 
        while start > 0 && line[start - 1] =~ '\a' 
            let start -= 1 
        endwhile 
        return start 
    else 
        while !exists("g:suggests")
            call EnUnqueue()
        endwhile
        " find months matching with "a:base" 
        let res = [] 
        for m in g:suggests
            if m =~ '^' . a:base 
                call add(res, m) 
            endif 
        endfor 
        unlet g:suggests
        return res 
    endif 
endfun 
" via ctrl+X ctrl+U
set completefunc=EnCompleteFunc
command! -nargs=0 EnComplete call EnComplete()
command! -nargs=0 EnType call EnType()
command! -nargs=0 EnTypeCheck call EnTypeCheck()
command! -nargs=0 EnDocUri call EnDocUri()
command! -nargs=0 EnDocBrowse call EnDocBrowse()
command! -nargs=0 EnUnqueue call EnUnqueue()
