# frozen_string_literal: true

require "prism"

class Hashira::Smells::Lineage
  MIXINS = %i[include prepend].freeze

  EXTENSIONS = %i[extend].freeze

  def initialize(types, foreign = Set.new, messages = Hashira::Runtime::Messages.new)
    @types = types
    @foreign = foreign
    @messages = messages
  end

  def assigned(context) = learned.fetch(context.to_s) { learned[context.to_s] = ancestral(context) }

  def settle(sketch, protocol) = sketch.settle(protocol, assigned(sketch), heirs(sketch))

  def heirs(context)
    name = context.to_s
    bequeathed = @_bequeathed ||= {}
    bequeathed.fetch(name) do
      bequeathed[name] = descendants(name).flat_map { |heir| index.fetch(heir).flat_map { writes(it) } }.uniq
    end
  end

  def pointed(type) = references(type).map { resolve(type.to_s, it) }

  def abroad(type) = references(type).reject { resolve(type.to_s, it) }.map { it.join("::") }

  def resolve(owner, segments) = candidates(owner, segments).find { it != owner && index.key?(it) }

  def definitions(type) = sweep(type).grep(Prism::DefNode).reject(&:receiver)

  def mixins(type) = named(type, MIXINS).filter_map { resolve(type.to_s, Hashira::Analysis::Syntax.new(it).segments) }

  def messages(type)
    swept = sweep(type)
    told = Set.new.compare_by_identity.merge(macros(type)).merge(swept.grep(Prism::AssocNode).map(&:key))
    swept.reject { told.include?(it) }.filter_map { message(type, it) }
  end

  def candidates(owner, segments)
    segments.empty? ? [] : scopes(owner).map { (it + segments).join("::") }
  end

  def known?(name) = index.key?(name)

  def sweep(type) = swept.fetch(type) { swept[type] = type.accept(Hashira::Smells::Scope).sweep }

  private

  def message(type, node)
    case node
    when Prism::CallNode then [node.name, addressee(type, node.receiver)]
    when Prism::SymbolNode then [Hashira::Analysis::Syntax::Word.new(node).symbol, nil]
    end
  end

  def addressee(type, receiver)
    return type.to_s if Hashira::Smells::Origin.new(receiver).self?
    built = receiver.is_a?(Prism::CallNode) && receiver.name == :new
    segments = Hashira::Analysis::Syntax.new(built ? receiver.receiver : receiver).segments
    candidates(type.to_s, segments).find { index.key?(it) } || segments if segments.any?
  end

  def descendants(name)
    found = [name]
    found.each { found.concat(children.fetch(it, []) - found) }
    found.drop(1)
  end

  def children
    @_children ||= @types.map { [descent(it), it.to_s] }.uniq.group_by(&:first).transform_values { it.map(&:last) }
  end

  def descent(type) = resolve(type.to_s, type.accept(Hashira::Smells::Heading).parent)

  def ancestral(context)
    kin = kin(context.to_s)
    return unless kin
    plantings = @_plantings ||= Hashira::Smells::Plantings.new(@types, self)
    planted = kin.map(&:to_s).uniq.flat_map { plantings.of(it) }
    (kin.flat_map { writes(it) } + planted + kin.flat_map { survey(it).computed }).uniq
  end

  def learned = @_learned ||= {}

  def index = @_index ||= @types.group_by(&:to_s)

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

  def opaque?(type) = veiled?(type) || @foreign.include?(type.to_s) || extensions(type).any? { stray?(type, it) }

  def stray?(type, node) = !resolve(type.to_s, Hashira::Analysis::Syntax.new(node).segments)

  def veiled?(type) = type.seat.class? && macros(type).map(&:name).any? { !native?(it) && !vocabulary.include?(it) }

  def native?(name) = @messages.macro?(name)

  def macros(type) = type.accept(Hashira::Analysis::Syntax::Body).to_a.grep(Prism::CallNode).reject(&:receiver)

  def vocabulary
    @_vocabulary ||= @types.flat_map { it.accept(Hashira::Analysis::TypeWalk).sections }.to_set { |definition, _| definition.name }
  end

  def extensions(type) = named(type, EXTENSIONS)

  def references(type) = named(type, MIXINS).map { Hashira::Analysis::Syntax.new(it).segments } + supers(type)

  def supers(type) = type.accept(Hashira::Smells::Heading).then { it.written.empty? ? [] : [it.parent] }

  def scopes(owner)
    parts = owner.split("::")
    parts.size.downto(0).map { parts.first(it) }
  end

  def writes(type) = survey(type).names

  def survey(type) = written.fetch(type) { written[type] = Hashira::Smells::Installs.new(type, sweep(type)) }

  def written = @_written ||= {}.compare_by_identity

  def named(type, names) = passed(calls(type).select { names.include?(it.name) })

  def passed(calls) = calls.flat_map { it.arguments.arguments }

  def calls(type) = sweep(type).grep(Prism::CallNode).reject(&:receiver).select(&:arguments)

  def swept = @_swept ||= {}.compare_by_identity
end
