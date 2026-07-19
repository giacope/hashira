# frozen_string_literal: true

module RuboCop
  module Cop
    module Hashira
      class IoDiscipline < Base
        MSG = "Write through the injected `@io`, not bare `%<method>s`."

        RESTRICT_ON_SEND = %i[puts warn pp p].freeze

        def_node_matcher :bare_output?, "(send nil? ${:puts :warn :pp :p} ...)"

        def on_send(node)
          bare_output?(node) do |method|
            add_offense(node, message: format(MSG, method:))
          end
        end
      end
    end
  end
end
