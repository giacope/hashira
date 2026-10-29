# frozen_string_literal: true

require "prism"
require_relative "course"
require_relative "lookup"
require_relative "readers"
require_relative "refs"

class Hashira::Smells::RepeatedCall < Hashira::Smells::Check
  OWNER = /[#.][^#.]+\z/

  class Calls
    def initialize(site, places, calls)
      @site = site
      @places = places
      @calls = calls
    end

    def to_h = { site: @site, places: @places, calls: @calls }

    def phrase(package)
      repeats = "#{Hashira::Prose::Count.new(@calls, "call")} in #{Hashira::Prose::Count.new(@places, "method")}"
      "#{package} repeats #{repeats} (#{@site}). Name the result in a local variable."
    end
  end

  class Repeat
    def initialize(kind, owner, site)
      @kind = kind
      @owner = owner
      @site = site
    end

    def finding(parts, testimony)
      calls = Calls.new(@site, parts.size, testimony.proof.to_a.size)
      testimony.finding(@kind, @owner, calls)
    end
  end

  def self.build(subject, rules)
    node = subject.node
    every = Hashira::Smells::Scope.new(node).inside(Prism::DefinedNode).grep(Prism::CallNode)
    discards = Hashira::Smells::Discards.new(node)
    pardons = Hashira::Smells::Pardons.new(
      subject, Hashira::Smells::Reachability.build(subject, every, discards), Hashira::Smells::Sampling.new(node, every)
    )
    groups = Hashira::Smells::CallGroups.new(
      every, Hashira::Smells::Steadiness.new(discards), Hashira::Smells::Bindings.new(node),
      Hashira::Smells::Enclosures.new(node)
    )
    new(subject, rules, groups, pardons)
  end

  def initialize(subject, rules, groups, pardons)
    super(subject, rules)
    @groups = groups
    @pardons = pardons
  end

  def findings = []

  def members
    return [] unless smelly?
    owner = label.sub(OWNER, "")
    lines = evidence.map { "#{label}: #{it}" }
    [member(:repeat, owner, Repeat.new(kind, owner, site), cited(lines, site))]
  end

  private

  def smelly? = repeats.any?

  def ratings = repeats.each_value.all? { @pardons.lesser?(it) } ? [:low] : []

  def repeats
    @_repeats ||= collapsed(outermost(together(@groups.to_h)).reject { |_, nodes| @pardons.excused?(nodes) })
  end

  def collapsed(groups)
    held = Set.new.compare_by_identity.merge(groups.values.flatten)
    groups.reject { |_handle, nodes| nodes.all? { prefixed?(it, held) } }
  end

  def prefixed?(node, held)
    receiver = node.receiver
    receiver.is_a?(Prism::CallNode) && (held.include?(receiver) || prefixed?(receiver, held))
  end

  def outermost(groups) = groups.reject { |_handle, nodes| echoed?(nodes, groups) }

  def echoed?(nodes, groups) = groups.each_value.any? { echoes?(nodes, it) }

  def echoes?(inner, outer) = inner.size == outer.size && inside?(inner, outer)

  def inside?(inner, outer) = inner.all? { nested?(it, outer) }

  def nested?(node, outer) = outer.any? { contains?(it, node) }

  def contains?(outer, node) = Hashira::Smells::Scope.new(outer).inside.any? { it.equal?(node) }

  def together(groups) = groups.select { |_handle, nodes| @pardons.reachable?(nodes) }

  def evidence
    repeats.map { |(handle, _), nodes| "#{handle} × #{nodes.size} (#{stamp(lines(nodes))})" }
  end

  def lines(nodes) = nodes.map { it.location.start_line }.uniq

  def stamp(lines) = "line#{"s" if lines.size > 1} #{lines.join(", ")}"
end
