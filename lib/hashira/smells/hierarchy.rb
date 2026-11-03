# frozen_string_literal: true

require "prism"

class Hashira::Smells::Hierarchy
  def initialize(
    types, builtins = Hashira::Runtime::Builtins.new, typeset = Hashira::Smells::Typeset.new(types),
    links = Hashira::Smells::Links.new(typeset, Hashira::Smells::Bodies.new)
  )
    @types = types
    @builtins = builtins
    @typeset = typeset
    @links = links
  end

  def inheritance = Hashira::Smells::Inheritance.new(openings, tree, @links)

  def tree = Hashira::Smells::Tree.new(parents)

  def births = Hashira::Smells::Births.new(openings, sites)

  def framing = Hashira::Smells::Framing.new(foreign, openings, tree)

  private

  def openings = @_openings ||= @types.group_by(&:to_s)

  def parents
    @_parents ||= openings.to_h { |name, opened| [name, ancestor(name, Hashira::Smells::Descent.new(opened).parent)] }
  end

  def foreign = @_foreign ||= openings.filter_map { |name, opened| name if unclaimed?(name, opened) }.to_set

  def unclaimed?(name, opened)
    Hashira::Smells::Descent.new(opened).parent? && parents.fetch(name).none? { claimed.include?(it) }
  end

  def ancestor(name, segments) = @typeset.resolve(name, segments).reject { @builtins.core?(it) }

  def claimed = @_claimed ||= @types.select { it.seat.claimed? }.to_set(&:to_s)

  def sites
    @_sites ||=
      {}.tap do |found|
        @types.each do |type|
          type.accept(Hashira::Smells::News).each do |call, factory|
            next if relayed?(type, call, factory)
            born(type, call).each { (found[it] ||= []) << type.seat.at(call.location.start_line) }
          end
        end
      end
  end

  def relayed?(type, call, factory) = !call.receiver && factory.is_a?(Symbol) && !summoned?(type.to_s, factory)

  def summoned?(name, selector)
    invocations.any? { |owner, call| call.name == selector && born(owner, call).include?(name) }
  end

  def invocations
    @_invocations ||=
      @types.flat_map do |type|
        type.accept(Hashira::Smells::Scope).sweep.grep(Prism::CallNode).select(&:receiver).map { [type, it] }
      end
  end

  def born(type, call)
    return [type.to_s] unless call.receiver
    candidates = @typeset.candidates(type.to_s, Hashira::Analysis::Syntax.new(call.receiver).segments)
    candidates.lazy.select { openings.key?(it) }.first(1)
  end
end
