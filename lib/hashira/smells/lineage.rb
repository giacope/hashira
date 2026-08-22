# frozen_string_literal: true

require "prism"

class Hashira::Smells::Lineage
  MIXINS = %i[include prepend].freeze

  EXTENSIONS = %i[extend].freeze

  WRITERS = %i[attr_writer attr_accessor].freeze

  SETTERS = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(types)
    @types = types
  end

  def assigned(context) = kin(context)&.flat_map { writes(it) }&.uniq

  def ancestry(context) = kin(context)

  private

  def index = @_index ||= @types.group_by(&:name)

  def kin(context) = walk([context.name], [])&.flat_map { index.fetch(it) }

  def walk(queue, known)
    return known if queue.empty?
    name, *rest = queue
    return walk(rest, known) if known.include?(name)
    onward(rest, known + [name], parents(index.fetch(name)))
  end

  def onward(queue, known, found)
    walk(queue + found, known) if found
  end

  def parents(kin)
    found = kin.flat_map { pointed(it) }
    found unless found.include?(nil) || kin.any? { opaque?(it) }
  end

  def opaque?(type) = extensions(type).any? { !resolve(type.name, Hashira::Analysis::Syntax.segments(it)) }

  def extensions(type) = named(type, EXTENSIONS)

  def pointed(type) = references(type).map { resolve(type.name, it) }

  def references(type)
    (named(type, MIXINS) + [parent(type)].compact).map { Hashira::Analysis::Syntax.segments(it) }
  end

  def parent(type) = (type.node.superclass if type.kind == :class)

  def resolve(owner, segments) = candidates(owner, segments).find { index.key?(it) }

  def candidates(owner, segments)
    segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }
  end

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end

  def writes(type)
    definitions(type).flat_map { setters(it) } + attributes(type)
  end

  def definitions(type) = sweep(type).grep(Prism::DefNode).reject(&:receiver)

  def setters(node) = Hashira::Smells::Scope.sweep(node).select { SETTERS.include?(it.class) }.map(&:name)

  def attributes(type)
    named(type, WRITERS).select { it.is_a?(Prism::SymbolNode) || it.is_a?(Prism::StringNode) }.map { :"@#{it.unescaped}" }
  end

  def named(type, names) = passed(calls(type).select { names.include?(it.name) })

  def passed(calls) = calls.flat_map { it.arguments.arguments }

  def calls(type) = sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)

  def sweep(type) = swept.fetch(type.node) { store(it) }

  def store(node) = swept[node] = Hashira::Smells::Scope.sweep(node)

  def swept = @_swept ||= {}.compare_by_identity
end
