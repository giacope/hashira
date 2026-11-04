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

  MIXINS = %i[module_function].freeze

  private_constant :MIXINS

  def initialize(subject, rules, refs, patrons)
    super(subject, rules)
    @refs = refs
    @patrons = patrons
  end

  private

  def smelly?
    standing = subject.standing
    !standing.singleton? && !standing.in?(MIXINS) && !standing.polymorphic? && @refs.lines.any? && envied.any?
  end

  def envied
    return @_envied if @_envied
    transit = subject.accept(Hashira::Smells::Transit, @refs)
    @_envied = @refs.envious.select { served(it).any? }.reject { excused?(it, transit) }
  end

  def excused?(holder, transit) = @patrons.dismiss?(holder) || paired?(holder) || transit.passing?(holder)

  def served(holder) = @patrons.of(holder)

  def paired?(holder) = @refs.envious.count { holder.beside?(it) } > 1

  def detail = Envy.new(site, envied.map(&:to_sym).uniq, types, Balance.new(count, @refs.lines.size))

  def count = @refs.lines(envied.first).size

  def types = envied.map { served(it).fetch(0).fetch(-1) }.uniq

  def evidence = envied.map { tally(it.to_sym, @refs.lines(it).uniq) } + [tally(:self, @refs.lines.uniq)]
end
