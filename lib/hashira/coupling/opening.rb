# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Opening
  def initialize(node, nesting, path, file)
    @node = node
    @nesting = nesting
    @path = path
    @file = file
  end

  def declared(census)
    [[@node, full, true], *written].map { |node, name, exposed| constant(census, node, name, exposed) }
      .select { census.owned?(it.to_a) }
  end

  def defined
    Hashira::Analysis::TypeWalk.new(@node).sections.map do |node, section|
      singleton = node.receiver || section == :singleton
      label = Hashira::Coupling::Label.new("#{shown}#{singleton ? "." : "#"}#{node.name}", @file, line(node))
      Hashira::Coupling::Routine.new(label, owner, node, section)
    end
  end

  private

  def body = Hashira::Analysis::Syntax::Body.new(@node)

  def full = @nesting.fetch(-1)

  def owner = body.class_level? ? @path[...-1] : @path

  def shown = (body.class_level? ? full[...-1] : full).join("::")

  def line(node) = node.location.start_line

  def written
    hidden = body.calls(:private_constant).flat_map { symbols(it) }.to_set
    body.constants.map do |node|
      name = node.name.to_s
      [node, [*full, name], !hidden.include?(name)]
    end
  end

  def symbols(call)
    call.arguments.arguments.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax::Word.new(it).to_s }
  end

  def constant(census, node, name, exposed)
    label = Hashira::Coupling::Label.new(name.join("::"), @file, line(node))
    Hashira::Coupling::Constant.new(label, census.strip(name), exposed)
  end
end
