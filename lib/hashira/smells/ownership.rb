# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(trees, catalog = nil)
    @trees = trees
    @catalog = catalog
  end

  def owned?(segments, owner = nil, rooted: false) = !place(segments, owner, rooted:).nil?

  def place(segments, owner, rooted: false) = (among(defined, segments, owner, rooted) unless segments.empty?)

  def anchored(segments, owner)
    kept = -> { segments.join("::") }
    segments.empty? ? segments : lexical(segments, owner).find(kept) { defined.include?(it) }.split("::")
  end

  def owns?(node, owner = nil)
    owned?(Hashira::Analysis::Syntax.new(node).segments, owner, rooted: Hashira::Analysis::Syntax.new(node).rooted?)
  end

  def vocabulary = @_vocabulary ||= Hashira::Smells::Vocabulary.new(@trees)

  def repertoire = @_repertoire ||= Hashira::Smells::Repertoire.new(@trees)

  def values = @_values ||= Hashira::Smells::Values.new(@trees)

  def nulls = @_nulls ||= Hashira::Smells::Nulls.new(@trees)

  def origin(segments, owner) = exports.origin(segments, owner)

  def callers = @_callers ||= Hashira::Smells::Callers.new(@trees, self)

  def resolve(segments, owner, rooted:) = among(written, segments, owner, rooted)

  def keys(segments) = tables.fetch(segments.join("::"), [])

  private

  def exports = @_exports ||= Hashira::Smells::Exports.new(@trees, self)

  def among(known, segments, owner, rooted)
    (rooted ? [segments.join("::")] : lexical(segments, owner)).find { known.include?(it) }
  end

  def defined = @_defined ||= claimed.flat_map { |node, full| [full, *named(node, full)] }.to_set { it.join("::") }

  def written = @_written ||= walked.to_set { |_node, full| full.join("::") }

  def tables
    @_tables ||= claimed.flat_map { |node, full| charted(node, full) }
      .flat_map { |path, keys| suffixes(path).map { [it, keys] } }.to_h
  end

  def walked
    @_walked ||= @trees.flat_map { Hashira::Analysis::TypeWalk.new(it).to_enum(:walk).map { |node, full| [node, full] } }
  end

  def claimed = @_claimed ||= walked.select { |_node, full| claimed?(full) }

  def named(node, full) = Hashira::Analysis::Syntax.new(node).constants.map { full + [it.name.to_s] }

  def charted(node, full)
    Hashira::Analysis::Syntax.new(node).constants.filter_map do |constant|
      keys = chart(Hashira::Analysis::Syntax.new(constant.value).thaw)
      [full + [constant.name.to_s], keys] if keys
    end
  end

  def lexical(segments, owner)
    parts = owner.to_s.split("::")
    parts.size.downto(0).map { (parts.first(it) + segments).join("::") }
  end

  def chart(value)
    return unless value.is_a?(Prism::HashNode)
    keys = value.elements.map { spine(it) }
    keys unless keys.empty? || keys.any?(&:nil?)
  end

  def spine(element)
    return unless element.is_a?(Prism::AssocNode)
    segments = Hashira::Analysis::Syntax.new(element.key).segments
    segments unless segments.empty?
  end

  def claimed?(full) = !@catalog || @catalog.claimed?(full)

  def suffixes(path)
    path.each_index.map { path.drop(it).join("::") }
  end
end
