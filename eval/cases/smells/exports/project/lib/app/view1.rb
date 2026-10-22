# frozen_string_literal: true

module App
  class View1
    def view1_0(node)
      node.is_a?(App::Ast::View) && node.type
    end

    def view1_1(node)
      node.is_a?(App::Ast::View) && node.type
    end

    def view1_2(node)
      node.is_a?(App::Ast::View) && node.type
    end

    def view1_3(node)
      node.is_a?(App::Ast::View) && node.type
    end
  end
end
