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

  NATIVE = Class.new.then { it.methods + it.private_methods }.to_set.freeze

  def initialize(types)
    @types = types
  end

  def assigned(context) = remember(learned, context.name) { ancestral(context) }

  def settle(sketch, **) = sketch.settle(assigned: assigned(sketch), heirs: heirs(sketch), **)

  def heirs(context) = remember(bequeathed, context.name) { descendants(it).flat_map { installs(it) }.uniq }

  def pointed(type) = references(type).map { resolve(type.name, it) }

  def resolve(owner, segments) = candidates(owner, segments).find { it != owner && index.key?(it) }

  def definitions(type) = sweep(type).grep(Prism::DefNode).reject(&:receiver)

  private

  def bequeathed = @_bequeathed ||= {}

  def installs(name) = index.fetch(name).flat_map { writes(it) }

  def descendants(name)
    found = [name]
    found.each { found.concat(children.fetch(it, []) - found) }
    found.drop(1)
  end

  def children
    @_children ||= @types.map { [descent(it), it.name] }.uniq.group_by(&:first).transform_values { it.map(&:last) }
  end

  def descent(type) = resolve(type.name, Hashira::Analysis::Syntax.segments(parent(type)))

  def ancestral(context) = kin(context)&.flat_map { writes(it) }&.uniq

  def learned = @_learned ||= {}

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

  def opaque?(type) = veiled?(type) || extensions(type).any? { stray?(type, it) }

  def stray?(type, node) = !resolve(type.name, Hashira::Analysis::Syntax.segments(node))

  def veiled?(type) = type.kind == :class && macros(type).any? { !NATIVE.include?(it) && !vocabulary.include?(it) }

  def macros(type)
    Hashira::Analysis::Syntax.statements(type.node).grep(Prism::CallNode).reject(&:receiver).map(&:name)
  end

  def vocabulary
    @_vocabulary ||= @types.flat_map { Hashira::Smells::Visibility.new(it.node).entries }.to_set { |definition, _| definition.name }
  end

  def extensions(type) = named(type, EXTENSIONS)

  def references(type)
    (named(type, MIXINS) + [parent(type)].compact).map { Hashira::Analysis::Syntax.segments(it) }
  end

  def parent(type) = (type.node.superclass if type.kind == :class)

  def candidates(owner, segments)
    segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }
  end

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end

  def writes(type) = remember(written, type.node) { definitions(type).flat_map { setters(it) } + attributes(type) }

  def written = @_written ||= {}.compare_by_identity

  def setters(node) = Hashira::Smells::Scope.sweep(node).select { SETTERS.include?(it.class) }.map(&:name)

  def attributes(type)
    named(type, WRITERS).select { it.is_a?(Prism::SymbolNode) || it.is_a?(Prism::StringNode) }.map { :"@#{it.unescaped}" }
  end

  def named(type, names) = passed(calls(type).select { names.include?(it.name) })

  def passed(calls) = calls.flat_map { it.arguments.arguments }

  def calls(type) = sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)

  def sweep(type) = remember(swept, type.node) { Hashira::Smells::Scope.sweep(it) }

  def remember(store, key) = store.fetch(key) { store[key] = yield(key) }

  def swept = @_swept ||= {}.compare_by_identity
end
