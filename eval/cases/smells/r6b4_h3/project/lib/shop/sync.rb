module Shop
  module Sync
    extend self

    def initialize
      @client = Client.new(ENV.fetch("TOKEN"))
    end

    def run
      initialize
      @client.pull
    end
  end
end
