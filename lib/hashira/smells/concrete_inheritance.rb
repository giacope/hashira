# frozen_string_literal: true

require "prism"

class Hashira::Smells::ConcreteInheritance < Hashira::Smells::Check
  SHOWN = 3

  CORE = %w[Array Hash String Set].freeze

  CONSTRUCTOR = :initialize

  Lineage = Data.define(:site, :parent, :home, :mode)

  private

  def smelly? = core? || (parent && !family.abstract?(parent) && (framed? ? overrides.any? : built.any?))

  def family = subject.family

  def parent = @_parent ||= family.parent(subject.subject)

  def core? = !parent && CORE.include?(base)

  def base
    written = subject.nodes.grep(Prism::ClassNode).filter_map(&:superclass).first
    Hashira::Analysis::Syntax.new(written).segments.join("::")
  end

  def framed? = family.framed?(parent)

  def built = family.built(parent)

  def overrides = @_overrides ||= subject.owned.select { working.include?(it.node.name) && !refusal?(it) }

  def working = @_working ||= family.definitions(parent).reject { refusal?(it) }.to_set { it.node.name } - [CONSTRUCTOR]

  def refusal?(method) = !Hashira::Smells::Refusal.new(method.node).of.nil?

  def mode
    return :core if core?
    framed? ? :overriding : :built
  end

  def detail = core? ? Lineage.new(site:, parent: base, home: site, mode:) : Lineage.new(site:, parent:, home:, mode:)

  def home = family.home(parent)

  def evidence
    case mode
    when :core then ["#{subject.subject} < #{base} (#{site})"]
    when :overriding then overrides.map { "#{it.subject} (#{it.site})" }
    else built.first(SHOWN).map { "#{parent}.new (#{it})" }
    end
  end
end
