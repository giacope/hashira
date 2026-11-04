# frozen_string_literal: true

require "prism"

class Hashira::Smells::Inheritance
  ABSTRACT = /\AAbstract|Base\z/

  MARKS = %i[abstract_class= abstract_class primary_abstract_class abstract!].freeze

  private_constant :ABSTRACT, :MARKS

  def initialize(openings, tree, links)
    @openings = openings
    @tree = tree
    @links = links
  end

  def definitions(name) = @openings.fetch(name, []).flat_map { it.reject { it.standing.singleton? } }

  def mixed(name) = @openings.fetch(name, []).flat_map { @links.mixins(it) }.flat_map { definitions(it) }

  def overrides(name, selector)
    @tree.descendants(name).flat_map { definitions(it) }.select { it.accept(Hashira::Smells::Signature).name == selector }
  end

  def abstract?(name)
    return true if ABSTRACT.match?(name.split("::").last)
    @openings.fetch(name, []).any? do |type|
      type.any? { !it.standing.singleton? && it.accept(Hashira::Smells::Refusal).unimplemented? } || marked?(type)
    end
  end

  private

  def marked?(type)
    type.accept(Hashira::Analysis::Syntax::Body).to_a.any? { it.is_a?(Prism::CallNode) && MARKS.include?(it.name) }
  end
end
