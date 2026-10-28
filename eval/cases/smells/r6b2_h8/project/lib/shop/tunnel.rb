# frozen_string_literal: true

module Shop
  class Tunnel
    def initialize(socket, routes, queue)
      @socket = socket
      @routes = routes
      @queue = queue
    end

    def handshake
      status = @socket.gets("\n")
      raise ArgumentError, status unless status.start_with?("HTTP/1.1 200")

      while (line = @socket.gets("\n"))
        break if line == "\r\n"
      end
      status
    end

    def pair = [@queue.pop(timeout: 1), @queue.pop(timeout: 1)]

    def route(host) = [@routes.fetch(host, :direct), @routes.fetch(host, :direct)]
  end
end
