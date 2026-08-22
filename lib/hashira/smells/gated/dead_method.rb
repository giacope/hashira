# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::DeadMethod < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_eval no_method_missing].freeze

  HOOKS = %i[initialize initialize_copy method_missing respond_to_missing?].freeze

  ASKERS = %i[send public_send __send__ method public_method respond_to?].freeze

  MARKERS = %i[private public protected module_function].freeze

  LITERALS = [Prism::SymbolNode, Prism::StringNode].freeze

  private

  def considers?(type) = type.kind == :class && asked(type).empty?

  def subjects(type) = sealed(type, HOOKS)

  def asked(type) = family.reach(type).grep(Prism::CallNode).select { guesses?(it) }

  def guesses?(node)
    ASKERS.include?(node.name) && !LITERALS.include?(node.arguments&.arguments&.first.class)
  end

  def entry(type, method)
    about(method, [method], sites(method), **stamp(method)) if lost?(type, method)
  end

  def sites(method) = [method.site]

  def stamp(method) = { section: method.section, names: [method.node.name] }

  def lost?(type, method) = spoken(type).count(method.node.name).zero?

  def spoken(type) = voices.fetch(type.node) { chart(type) }

  def chart(type)
    marked = markers(type)
    voices[type.node] = family.reach(type).reject { marked.include?(it) }.flat_map { mention(it) }
  end

  def markers(type)
    labels = family.reach(type).grep(Prism::CallNode).select { marker?(it) }.flat_map { given(it) }
    Set.new.compare_by_identity.merge(labels.select { LITERALS.include?(it.class) })
  end

  def marker?(node) = MARKERS.include?(node.name) && !node.receiver

  def given(call) = call.arguments&.arguments || []

  def mention(node)
    return [node.name] if node.is_a?(Prism::CallNode)
    LITERALS.include?(node.class) ? [node.unescaped.to_sym] : []
  end

  def voices = @_voices ||= {}.compare_by_identity
end
