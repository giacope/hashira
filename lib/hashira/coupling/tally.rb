# frozen_string_literal: true

class Hashira::Coupling::Tally
  def initialize(roster, layout, folding)
    @roster = roster
    @layout = layout
    @folding = folding
  end

  def to_a = @roster.to_a | @layout.to_a

  def to_h = @roster.to_h

  def to_s = @layout.to_s

  def folds = @folding.disclosed

  def links(packages, dependencies)
    packages.to_h do |package|
      [package, @layout.test?(package) ? Set.new : dependencies[package].reject { aside?(it) }.to_set]
    end
  end

  def aside?(package) = @layout.aside?(package)

  def root = @layout.root
end
