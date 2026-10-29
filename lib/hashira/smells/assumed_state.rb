# frozen_string_literal: true

require "prism"

class Hashira::Smells::AssumedState < Hashira::Smells::Check
  MAYBES = [
    Prism::LocalVariableOrWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::ClassVariableOrWriteNode, Prism::GlobalVariableOrWriteNode,
    Prism::ConstantOrWriteNode, Prism::ConstantPathOrWriteNode,
    Prism::CallOrWriteNode, Prism::IndexOrWriteNode
  ].freeze

  class Assumption
    def initialize(site, installed, unassigned)
      @site = site
      @installed = installed
      @unassigned = unassigned
    end

    def to_h = { site: @site, installed: @installed, unassigned: @unassigned }

    def phrase(package)
      "#{package} reads instance variables nothing in the class assigns (#{@site}). " \
        "#{[*orphaned, *installing].join(" ")}"
    end

    private

    def orphaned
      return [] if @unassigned.empty?
      single = @unassigned.one?
      reads = single ? "it reads" : "they read"
      said = "Nothing ever assigns #{Hashira::Prose::Quoted.new(@unassigned)}, so #{reads} nil: " \
        "a typo or a dead hook. Assign #{single ? "it" : "them"} where the object is built, or delete the read."
      [said]
    end

    def installing
      return [] if @installed.empty?
      said = "Its subclasses are expected to install #{Hashira::Prose::Quoted.new(@installed)}; " \
        "pass #{@installed.one? ? "it" : "them"} in instead."
      [said]
    end
  end

  class Harvest
    def initialize(node)
      @node = node
    end

    def reads
      return [] if MAYBES.include?(node.class)
      below = node.compact_child_nodes.grep_v(Prism::DefNode).flat_map { Harvest.new(it).reads }
      node.is_a?(Prism::InstanceVariableReadNode) ? below + [node.name] : below
    end

    private

    attr_reader :node
  end

  private

  def smelly? = subject.kind == :class && subject.claimed? && assigned && assumed.any? && legible?

  def legible? = subject.legible?

  def assigned = subject.assigned

  def assumed = @_assumed ||= (read - assigned).uniq.sort.reject { cache?(it) || computed?(it) }

  def cache?(name) = name.start_with?("@_")

  def computed?(name) = assigned.grep(String).any? { name.start_with?(it) }

  def read = subject.owned.flat_map { Harvest.new(it.node).reads }

  def installed = assumed & subject.heirs

  def detail = Assumption.new(site, installed.map(&:to_s), (assumed - installed).map(&:to_s))

  def evidence = assumed.map(&:to_s)
end
