# frozen_string_literal: true

require "prism"

class Hashira::Smells::Lineage
  MIXINS = %i[include prepend].freeze

  EXTENSIONS = %i[extend].freeze

  def initialize(types, foreign = Set.new)
    @types = types
    @foreign = foreign
  end

  def assigned(context) = learned.fetch(context.name) { learned[context.name] = ancestral(context) }

  def settle(sketch, **) = sketch.settle(assigned: assigned(sketch), heirs: heirs(sketch), **)

  def heirs(context)
    name = context.name
    bequeathed = @_bequeathed ||= {}
    bequeathed.fetch(name) do
      bequeathed[name] = descendants(name).flat_map { |heir| index.fetch(heir).flat_map { writes(it) } }.uniq
    end
  end

  def pointed(type) = references(type).map { resolve(type.name, it) }

  def resolve(owner, segments) = candidates(owner, segments).find { it != owner && index.key?(it) }

  def definitions(type) = sweep(type).grep(Prism::DefNode).reject(&:receiver)

  def mixins(type) = named(type, MIXINS).filter_map { resolve(type.name, Hashira::Analysis::Syntax.new(it).segments) }

  def messages(type) = sweep(type).filter_map { message(it) }

  def candidates(owner, segments)
    segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }
  end

  def known?(name) = index.key?(name)

  def sweep(type) = swept.fetch(type.node) { swept[type.node] = Hashira::Smells::Scope.new(type.node).sweep }

  private

  def message(node)
    case node
    when Prism::CallNode then node.name
    when Prism::SymbolNode then Hashira::Analysis::Syntax.new(node).symbol
    end
  end

  def descendants(name)
    found = [name]
    found.each { found.concat(children.fetch(it, []) - found) }
    found.drop(1)
  end

  def children
    @_children ||= @types.map { [descent(it), it.name] }.uniq.group_by(&:first).transform_values { it.map(&:last) }
  end

  def descent(type) = resolve(type.name, Hashira::Analysis::Syntax.new(parent(type)).segments)

  def ancestral(context)
    kin = kin(context.name)
    return unless kin
    planted = kin.map(&:name).uniq.flat_map { plantings.of(it) }
    (kin.flat_map { writes(it) } + planted + kin.flat_map { survey(it).computed }).uniq
  end

  def learned = @_learned ||= {}

  def plantings = @_plantings ||= Hashira::Smells::Plantings.new(@types, self)

  def index = @_index ||= @types.group_by(&:name)

  def kin(name) = walk([name], [])&.flat_map { index.fetch(it) }

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

  def opaque?(type) = veiled?(type) || @foreign.include?(type.name) || extensions(type).any? { stray?(type, it) }

  def stray?(type, node) = !resolve(type.name, Hashira::Analysis::Syntax.new(node).segments)

  def veiled?(type) = type.kind == :class && macros(type).any? { !native?(it) && !vocabulary.include?(it) }

  def native?(name) = Hashira::Analysis::MACROS.include?(name)

  def macros(type)
    Hashira::Analysis::Syntax.new(type.node).statements.grep(Prism::CallNode).reject(&:receiver).map(&:name)
  end

  def vocabulary
    @_vocabulary ||= @types.flat_map { Hashira::Analysis::TypeWalk.new(it.node).sections }.to_set { |definition, _| definition.name }
  end

  def extensions(type) = named(type, EXTENSIONS)

  def references(type)
    (named(type, MIXINS) + [parent(type)].compact).map { Hashira::Analysis::Syntax.new(it).segments }
  end

  def parent(type) = (type.node.superclass if type.kind == :class)

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end

  def writes(type) = survey(type).names

  def survey(type) = written.fetch(type.node) { written[type.node] = Hashira::Smells::Installs.new(type, sweep(type)) }

  def written = @_written ||= {}.compare_by_identity

  def named(type, names) = passed(calls(type).select { names.include?(it.name) })

  def passed(calls) = calls.flat_map { it.arguments.arguments }

  def calls(type) = sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)

  def swept = @_swept ||= {}.compare_by_identity
end
