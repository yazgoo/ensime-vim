require 'spec_helper'
require 'websocket-eventmachine-client'
require_relative '../src/ensime'
class FakeSocket
    def send what
    end
end
class FakeClient
    def readline
        "unqueue"
    end
    def puts what
    end
    def close
    end
end
class TCPServer
    def initialize a, b
    end
    def addr
        [nil, 42]
    end
    def accept
        @i ||= 0
        client = FakeClient.new
        @i += 1
        @i == 1 ? client : nil
    end
end
module WebSocket
    module EventMachine
        class Client
            def connect blah
            end
        end
    end
end
describe EnsimeBridge do
    bridge = EnsimeBridge.new("/tmp")
    bridge.socket = FakeSocket.new
    it "position for row 1, col 1 should return 0" do
        expect(bridge.to_position(__FILE__, 1, 1)).to be 0
    end
    it "unqueue should return nil with no server" do
        expect(bridge.unqueue).to be_nil
    end
    it "at_point should be nil" do
        expect(bridge.at_point(__FILE__, 0, 0, 0, 0)).to be_nil
    end
    it "type should be nil" do
        expect(bridge.type(__FILE__, 0, 0, 0)).to be_nil
    end
    it "doc_uri should be nil" do
        expect(bridge.doc_uri(__FILE__, 0, 0, 0)).to be_nil
    end
    it "complete should be nil" do
        expect(bridge.complete(__FILE__, 0, 0)).to be_nil
    end
    it "typecheck should be nil" do
        expect(bridge.typecheck(__FILE__)).to be_nil
    end
    it "run should work" do
        Dir.mkdir(bridge.cache) if not File.exists? bridge.cache
        bridge.run
    end
    it "connect_to_ensime should be nil" do
        File.write(bridge.cache + "http", "")
        bridge.connect_to_ensime
    end
end
