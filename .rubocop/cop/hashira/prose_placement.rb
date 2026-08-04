# frozen_string_literal: true

module RuboCop
  module Cop
    module Hashira
      class ProsePlacement < Base
        MSG = "Prose belongs to the presentation layer (report/, ci/) — pass data and phrase it there."

        WORDS = 5

        def on_str(node)
          add_offense(node) if prose?(node.value) && !exempt?(node)
        end

        def on_dstr(node)
          text = node.each_child_node(:str).map(&:value).join(" ")
          add_offense(node) if prose?(text) && !exempt?(node)
        end

        private

        def prose?(text) = text.split(/\s+/).count { it.match?(/\A[A-Za-z][a-z]*[,.:;]?\z/) } >= WORDS

        def exempt?(node)
          node.each_ancestor(:send).any? { it.method?(:raise) } || node.each_ancestor(:dstr).any?
        end
      end
    end
  end
end
