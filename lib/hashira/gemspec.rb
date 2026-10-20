# frozen_string_literal: true

class Hashira::Gemspec
  def initialize(path)
    @path = path
  end

  def paths
    nodes(Hashira::Trees.parse(@path)).grep(Prism::CallNode).select { it.name == :require_paths= }
      .flat_map { strings(it.arguments.arguments.first) }.flat_map { Dir[it] }.select { Dir["#{it}/**/*.rb"].any? }
  end

  private

  def nodes(node) = [node, *node.compact_child_nodes.flat_map { nodes(it) }]

  def strings(value)
    case value
    when Prism::ArrayNode then value.elements.flat_map { strings(it) }
    when Prism::StringNode then [value.unescaped]
    when Prism::CallNode then [value.receiver, *value.arguments&.arguments].compact.flat_map { strings(it) }
    else []
    end
  end
end
