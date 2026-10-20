# frozen_string_literal: true

class Hashira::Gemspec
  def initialize(path)
    @path = path
  end

  def paths = globs.flat_map { Dir[it] }.select { Dir["#{it}/**/*.rb"].any? }

  private

  def globs = written.flat_map { strings(it.arguments.arguments.first) }

  def written = nodes(Prism.parse_file(@path).value).grep(Prism::CallNode).select { it.name == :require_paths= }

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
