# frozen_string_literal: true

module App
  module Ast
    %i[CallNode DefNode].each { |name| const_set(name, Prism.const_get(name)) }

    class View
      def initialize(node)
        @node = node
      end
    end
  end

  module Types
    App::Ast.constants.each { |name| const_set(name, App::Ast.const_get(name)) }
  end

  Node = Parser::AST::Node
end
