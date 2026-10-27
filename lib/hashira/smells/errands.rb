# frozen_string_literal: true

require "prism"

class Hashira::Smells::Errands
  FLOW = Hashira::Smells::Tails.new(Hashira::Smells::Tails::FLOW)

  def initialize(home)
    @home = home
  end

  def own?(call) = Hashira::Smells::Origin::SELVES.include?(call.receiver.class) && definitions.key?(call.name)

  def of(name)
    reaches.fetch(name) do
      found = [name]
      found.each { |each| found.concat(called(each) - found) }
      reaches[name] = found.flat_map { acts(it) }
    end
  end

  private

  def called(name) = body(name).grep(Prism::CallNode).select { own?(it) }.map(&:name)

  def acts(name)
    definition = definitions.fetch(name)
    nodes = body(name)
    voids = Hashira::Smells::Discards.new(definition)
    answers = FLOW.reach([definition.body, *nodes.grep(Prism::ReturnNode).filter_map(&:arguments).flat_map(&:arguments)].compact)
    nodes.select { voids.include?(it) || answers.include?(it) || it.is_a?(Prism::InstanceVariableWriteNode) }
  end

  def body(name) = Hashira::Smells::Scope.new(definitions.fetch(name)).inside

  def definitions
    @_definitions ||= Hashira::Analysis::TypeWalk.new(@home).sections.to_h { |definition, _| [definition.name, definition] }
  end

  def reaches = @_reaches ||= {}
end
