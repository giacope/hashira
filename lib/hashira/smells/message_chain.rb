# frozen_string_literal: true

require "prism"

class Hashira::Smells::MessageChain < Hashira::Smells::Check
  MESSAGES = Hashira::Runtime::Messages.new

  class Chain
    def initialize(kind, site, through, places)
      @kind = kind
      @site = site
      @through = through
      @places = places
    end

    def to_h = { site: @site, places: @places, through: @through }

    def phrase(package)
      near, far = @through
      reaching = "#{Hashira::Prose::Count.new(@places, "method")} reach#{"es" if @places == 1} through"
      "#{package} — #{reaching} #{near} into #{far} (#{@site}). Ask #{near} for what you need, or hand the #{far} in."
    end

    def finding(parts, testimony)
      testimony.finding(@kind, @through.join(" → "), Chain.new(@kind, @site, @through, parts.size))
    end
  end

  def findings = []

  def members
    return [] unless smelly?
    through = path(chains.first.receiver).first(2)
    [member(:chain, through, Chain.new(kind, site, through, 1), cited(["#{label} (#{site})"], site))]
  end

  private

  def smelly? = chains.any?

  def initialize(subject, rules, words, names)
    super(subject, rules)
    @words = words
    @names = names
  end

  def chains
    @_chains ||=
      begin
        found = Hashira::Smells::Scope.new(subject.node).inside.grep(Prism::CallNode).select { chained?(it) }
        found.reject { |call| found.any? { it.receiver.equal?(call) } }
      end
  end

  def chained?(call)
    hop = call.receiver
    return false unless hop.is_a?(Prism::CallNode) && !inward?(hop.receiver) && !hop.block
    far = type(hop)
    far.any? && answers?(far.first, call.name) && !@words.value?(far.first)
  end

  def answers?(type, message)
    !MESSAGES.universal?(message) && @words.of([type]).include?(message.to_s.delete_suffix("="))
  end

  def type(node)
    case node
    when Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode then named(node.name)
    when Prism::CallNode then node.arguments ? [] : step(node)
    else []
    end
  end

  def step(call)
    message = call.name
    return named(message) if inward?(call.receiver)
    near = type(call.receiver)
    far = named(message)
    near.any? && near != far && answers?(near.first, message) ? far : []
  end

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def named(name)
    types = Hashira::Smells::Naming.new(name.to_s.delete_prefix("@")).types.map(&:first)
    types.lazy.select { @names.place([it], subject.owner).any? }.first(1)
  end

  def path(node)
    node.is_a?(Prism::CallNode) && !inward?(node.receiver) ? path(node.receiver) + type(node) : type(node)
  end
end
