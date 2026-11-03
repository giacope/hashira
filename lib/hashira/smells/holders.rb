# frozen_string_literal: true

require "prism"

class Hashira::Smells::Holders
  def initialize(subject, foreign, names, ties)
    @subject = subject
    @foreign = foreign
    @names = names
    @ties = ties
  end

  def of(receiver)
    case receiver
    when Prism::InstanceVariableReadNode then field(receiver.name)
    when Prism::LocalVariableReadNode then sole(kinds(receiver.name))
    when Prism::CallNode then built(receiver)
    else []
    end
  end

  def sprung(call) = of(call.receiver).select { @ties.null?(it, call.name) }.map { "#{it}##{call.name}" }

  def answers?(receiver) = @names.answers?(receiver, owner)

  def origin(node) = Hashira::Smells::Origin.new(node).of(@subject, @ties)

  private

  def owner = @subject.owner

  def field(name)
    written = @ties.types(name, owner)
    return sole(written - [owner]) unless written.empty?
    sole(Hashira::Smells::Naming.new(name.to_s.delete_prefix("@")).types.flat_map { place(it) }.first(1) - [owner])
  end

  def kinds(local) = @foreign.kinds(Hashira::Smells::Refs::Local.new(local, @subject.node)).map { it.join("::") }

  def built(call) = call.name == :new ? place(Hashira::Analysis::Syntax.new(call.receiver).segments) : []

  def place(segments) = @names.place(segments, owner)

  def sole(found) = Hashira::Smells::Sole.new(found).to_a
end
