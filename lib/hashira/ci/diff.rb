# frozen_string_literal: true

class Hashira::CI::Diff
  def initialize(added, removed, worsened)
    @added = added
    @removed = removed
    @worsened = worsened
  end

  def empty? = @added.empty? && @removed.empty? && @worsened.empty?

  def worse? = !@added.empty? || !@worsened.empty?

  def told(changes) = changes.list(@added, @worsened, @removed)

  def unremoved = Hashira::CI::Diff.new(@added, [], @worsened)
end
