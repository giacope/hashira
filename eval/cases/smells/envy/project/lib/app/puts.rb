module Lint
  class Puts
    def initialize = @offenses = []

    def on_send(node)
      return unless node.method?(:puts) && node.receiver.nil?
      add_offense(node.loc.selector, message: "avoid #{node.method_name}")
    end

    private

    def add_offense(range, message:) = @offenses << [range, message]
  end
end
