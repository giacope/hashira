# frozen_string_literal: true

require "prism"

class Hashira::Smells::Lineage
  EXTENSION = :extend

  MESSAGES = Hashira::Runtime::Messages.new

  private_constant :EXTENSION, :MESSAGES

  def initialize(
    types, typeset = Hashira::Smells::Typeset.new(types), plantings = Hashira::Smells::Plantings.new(types, typeset),
    links = Hashira::Smells::Links.new(typeset)
  )
    @types = types
    @typeset = typeset
    @plantings = plantings
    @links = links
  end

  def settle(sketch, protocol) = sketch.settle(protocol, assigned(sketch), heirs(sketch))

  private

  def assigned(context)
    learned = @_learned ||= {}
    learned.fetch(context.to_s) { learned[context.to_s] = ancestral(context) }
  end

  def heirs(context)
    name = context.to_s
    bequeathed = @_bequeathed ||= {}
    bequeathed.fetch(name) do
      bequeathed[name] = descendants(name).flat_map { |heir| index.fetch(heir).flat_map { writes(it) } }.uniq
    end
  end

  def descendants(name)
    found = [name]
    found.each { found.concat(children.fetch(it, []) - found) }
    found.drop(1)
  end

  def children
    return @_children if @_children
    pairs =
      @types.flat_map do |type|
        @typeset.resolve(type.to_s, type.accept(Hashira::Smells::Heading).parent).map { [it, type.to_s] }
      end
    @_children = pairs.uniq.group_by(&:first).transform_values { it.map(&:last) }
  end

  def ancestral(context)
    walk([context.to_s], []).map do |names|
      kin = names.flat_map { index.fetch(it) }
      (kin.flat_map { writes(it) } + names.flat_map { @plantings.of(it) } + kin.flat_map { survey(it).computed }).uniq
    end
  end

  def index = @_index ||= @types.group_by(&:to_s)

  def walk(queue, known)
    return [known] if queue.empty?
    name, *rest = queue
    return walk(rest, known) if known.include?(name)
    parents(index.fetch(name)).flat_map { walk(rest + it, known + [name]) }
  end

  def parents(kin)
    kin.any? { @links.abroad(it).any? || opaque?(it) } ? [] : [kin.flat_map { @links.pointed(it) }]
  end

  def opaque?(type)
    name = type.to_s
    veiled?(type) || (@_foreign ||= @types.reject { it.seat.claimed? }.to_set(&:to_s)).include?(name) || stray?(type)
  end

  def stray?(type)
    calls = @typeset.sweep(type).grep(Prism::CallNode).select { !it.receiver && it.arguments && it.name == EXTENSION }
    calls.flat_map { it.arguments.arguments }.any? { unknown?(type, it) }
  end

  def unknown?(type, node) = @typeset.resolve(type.to_s, Hashira::Analysis::Syntax.new(node).segments).empty?

  def veiled?(type)
    return false unless type.seat.class?
    macros = type.accept(Hashira::Analysis::Syntax::Body).to_a.grep(Prism::CallNode).reject(&:receiver).map(&:name)
    macros.any? { !MESSAGES.macro?(it) && !vocabulary.include?(it) }
  end

  def vocabulary
    @_vocabulary ||=
      @types.flat_map { it.accept(Hashira::Analysis::TypeWalk).sections }.to_set { |definition, _| definition.name }
  end

  def writes(type) = survey(type).names

  def survey(type) = written.fetch(type) { written[type] = Hashira::Smells::Installs.new(type, @typeset.sweep(type)) }

  def written = @_written ||= {}.compare_by_identity
end
