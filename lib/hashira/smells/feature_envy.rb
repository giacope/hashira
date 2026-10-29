# frozen_string_literal: true

require "prism"

class Hashira::Smells::FeatureEnvy < Hashira::Smells::Check
  class Envy
    def initialize(site, names, types, balance)
      @site = site
      @names = names
      @types = types
      @balance = balance
    end

    def to_h = { site: @site, names: @names, types: @types, **@balance.to_h }

    def phrase(package)
      "#{package} refers to #{Hashira::Prose::Quoted.new(@names)} more than to self, #{@balance.phrase(@names)} " \
        "(#{@site}). The behavior may belong on #{choices}."
    end

    private

    def choices = [@types[0..-2].join(", "), @types.last].reject(&:empty?).join(" or ")
  end

  class Balance
    def initialize(count, ego)
      @count = count
      @ego = ego
    end

    def to_h = { count: @count, ego: @ego }

    def phrase(names) = "#{@count}#{" each" unless names.one?} to #{@ego}"
  end

  private

  def smelly?
    !subject.singleton? && !subject.mixin? && !subject.polymorphic? && refs.ego.positive? && envied.any?
  end

  def refs = @_refs ||= Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def envied = @_envied ||= refs.envious.select { served(it).any? }.reject { excused?(it) }

  def excused?(holder) = foreign.dismiss?(holder) || paired?(holder) || transit.passing?(holder)

  def served(holder) = foreign.kinds(holder).select { serves?(it, holder) }

  def serves?(type, holder) = asked(holder, type).subset?(repertoire.of(type))

  def asked(holder, type)
    seen = repertoire.closed?(type) ? refs.sends(holder) : refs.reads(holder)
    seen.to_set { it.name.to_s.delete_suffix("=") }
  end

  def repertoire = subject.ownership.repertoire

  def transit = @_transit ||= Hashira::Smells::Transit.new(subject.node, refs)

  def paired?(holder) = partners(holder.scope) > 1

  def partners(scope) = scope.is_a?(Prism::BlockNode) ? refs.envious.count { it.scope == scope } : 0

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def detail = Envy.new(site, envied.map(&:name).uniq, types, Balance.new(count, refs.ego))

  def count = refs.lines(envied.first).size

  def types = envied.map { served(it).fetch(0).fetch(-1) }.uniq

  def evidence = envied.map { tally(it.name, refs.lines(it).uniq) } + [tally(:self, refs.ego_lines.uniq)]
end
