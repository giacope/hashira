# frozen_string_literal: true

require "prism"

class Hashira::Smells::DataClass < Hashira::Smells::Check
  CONSTRUCTOR = :initialize

  MINIMUM = 2

  class Holding
    DATA_CLASS = "Move the code that works on these fields into the class."

    BAGGED = "Move that code into the class, so the data and what it means live together."

    def initialize(site, fields, users = [])
      @site = site
      @fields = fields
      @users = users
    end

    def to_h = { site: @site, fields: @fields, users: @users.first }.compact

    def phrase(package)
      said = "holds #{Hashira::Prose::Quoted.new(@fields)} and does nothing else"
      return "#{package} #{said} (#{@site}). #{DATA_CLASS}" if @users.empty?
      users = @users.fetch(0)
      elsewhere = "#{Hashira::Prose::Count.new(users, "method")} elsewhere compute#{"s" if users == 1} with them"
      "#{package} #{said}, while #{elsewhere} (#{@site}). #{BAGGED}"
    end
  end

  private

  def smelly? = subject.kind == :class && unrelated? && statements.all? { plain?(it) } && fields.size >= MINIMUM

  def unrelated?
    subject.nodes.grep(Prism::ClassNode).none?(&:superclass) && subject.family.children(subject.subject).empty?
  end

  def statements = @_statements ||= subject.statements

  def plain?(node)
    case node
    when Prism::CallNode then Hashira::Smells::Attributes.new([node]).macros.any? || Hashira::Analysis::Syntax::Call.new(node).marker?
    when Prism::DefNode then !node.receiver && (node.name == CONSTRUCTOR ? stores?(node) : access?(node))
    else false
    end
  end

  def body(definition) = Hashira::Analysis::Syntax::Body.new(definition).to_a.compact

  def stores?(definition) = body(definition).all? { it.is_a?(Prism::InstanceVariableWriteNode) && given?(it.value) }

  def given?(value) = value.is_a?(Prism::LocalVariableReadNode) || value.is_a?(Prism::NilNode)

  def access?(definition)
    held = body(definition)
    held.one? && (held.first.is_a?(Prism::InstanceVariableReadNode) || stores?(definition))
  end

  def fields = @_fields ||= (Hashira::Smells::Attributes.new(statements).declared + stored).uniq

  def stored
    statements.grep(Prism::DefNode).flat_map { body(it) }.grep(Prism::InstanceVariableWriteNode).map { it.name.to_s.delete_prefix("@") }
  end

  def detail = Holding.new(site, fields)

  def evidence = fields
end
