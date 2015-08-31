#!/usr/bin/env ruby
require 'websocket-eventmachine-client'
require 'json'
require 'thread'
require_relative 'ensime'
class EnsimeBridge
    attr_accessor :socket
    attr_reader :cache
    def get_socket file
        TCPSocket.open("localhost", File.read(file).chomp)
    end
    def is_running? file = nil
        file = file.nil? ? @bridge_file : file
        return false if not File.exists? file
        begin
            get_socket(file).close
        rescue => e
            return false
        end
        true
    end
    def initialize path
        @ensime = Ensime.new(path).run
        @cache = "#{path}_cache/"
        @queue = Queue.new
        @bridge_file = "#{@cache}bridge"
        @http_file = "#{@cache}http"
    end
    def remote_stop
        s = get_socket(@bridge_file)
        s.puts "self.stop"
        s.close
    end
    def stop
        @ensime.stop
        exit
    end
    def connect_to_ensime
        url = "ws://127.0.0.1:#{File.read("#{@cache}http").chomp}/jerky"
        @socket = WebSocket::EventMachine::Client.connect(:uri => url)
        @socket.onopen do
            puts "Connected!"
        end
        @socket.onerror do |err|
            p err
        end
        @socket.onmessage do |msg, type|
            puts "Received message: #{msg}, type #{type}"
            @queue << msg
        end
        @socket.onclose do |code, reason|
            puts "Disconnected with status code: #{code} #{reason}"
        end
    end
    def json packet
        s = packet.to_json
        Kernel.puts " to server => #{s}"
        @socket.send s
    end
    def req message
        @i ||= 0
        @i += 1
        json({"callId" => @i,"req" => message})
    end
    def unqueue
        if @queue.size == 0
            nil
        else
            @queue.pop(true)
        end
    end
    def wait_for_ensime
        while not is_running? @http_file
            sleep 0.2
        end
    end
    def run
        if is_running?
            puts "bridge is already running"
            return
        end
        wait_for_ensime
        puts "ensime is ready"
        Thread.new do
            EventMachine.run do
                connect_to_ensime
            end
        end
        server = TCPServer.new "localhost", 0
        File.write(@bridge_file, server.addr[1])
        while @client = server.accept
            begin
                command = @client.readline.chomp
                while true
                    result = instance_eval command
                    if command == "unqueue"
                        if not result.nil? and not result.empty?
                            @client.puts result.gsub("\n", "")
                        else
                            @client.puts "nil"
                            break
                        end
                        puts result.gsub("\n", "")
                    else
                        break
                    end
                end
                @client.close
            rescue => e
                p e
                puts e.backtrace
            end
        end
    end
    def to_position path, row, col
        i = -1
        File.open(path) do |f|
            (row - 1).times do
                i += f.readline.size
            end
            i += col
        end
        i
    end
    def at_point what, path, row, col, size, where = "range"
        i = to_position path, row, col
        req({"typehint" => what + "AtPointReq",
            "file" => path,
            where => {"from" => i,"to" => i + size}})
    end
    def type path, row, col, size
        at_point "Type", path, row, col, size
    end
    def doc_uri path, row, col, size
        at_point "DocUri", path, row, col, size, "point"
    end
    def complete path, row, col
        i = to_position path, row, col
        req({"point"=>i, "maxResults"=>100,"typehint"=>"CompletionsReq",
            "caseSens"=>true,"fileInfo"=>{"file"=>path},"reload"=>false})
    end
    def typecheck path
        req({"typehint"=>"TypecheckFilesReq","files" => [path]})
    end
end
EnsimeBridge.new(ARGV.size == 0 ? ".ensime" : ARGV[0]).run if __FILE__ == $0
