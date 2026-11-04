# frozen_string_literal: true

class Hashira::Smells::Ownership
  def initialize(walk, catalog)
    @walk = walk
    @catalog = catalog
  end

  def place(segments, owner, rooted: false) = segments.empty? ? [] : among(defined, segments, owner, rooted)

  def placed(node, owner)
    place(Hashira::Analysis::Syntax.new(node).segments, owner, rooted: Hashira::Analysis::Syntax.new(node).rooted?)
  end

  def resolve(segments, owner, rooted:) = among(written, segments, owner, rooted)

  def anchored(segments, owner)
    kept = -> { segments.join("::") }
    segments.empty? ? segments : lexical(segments, owner).find(kept) { defined.include?(it) }.split("::")
  end

  private

  def among(known, segments, owner, rooted)
    Array((rooted ? [segments.join("::")] : lexical(segments, owner)).find { known.include?(it) })
  end

  def defined
    @_defined ||= (claimed.map(&:last) + @walk.constants(@catalog).map(&:first)).to_set { it.join("::") }
  end

  def written = @_written ||= @walk.to_a.to_set { |_node, full| full.join("::") }

  def claimed = @_claimed ||= @walk.claimed(@catalog)

  def lexical(segments, owner)
    parts = owner.to_s.split("::")
    parts.size.downto(0).map { (parts.first(it) + segments).join("::") }
  end
end
