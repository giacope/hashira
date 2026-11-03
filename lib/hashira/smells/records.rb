# frozen_string_literal: true

require "prism"

class Hashira::Smells::Records
  RECORD = /(?:\A|::)(?:ApplicationRecord|ActiveRecord::Base)\z/

  SHAPES = %i[
    belongs_to has_one has_many has_and_belongs_to_many scope enum attribute store_accessor serialize
    self.table_name= self.primary_key=
  ].freeze

  def initialize(types, family)
    @types = types
    @family = family
  end

  def bags
    @types.group_by(&:to_s).filter_map do |name, openings|
      Hashira::Smells::Bags::Bag.new(name:, site: openings.first.seat.at, fields: nil) if bare?(name, openings)
    end
  end

  private

  def bare?(name, openings) = openings.all? { plain?(it) } && [name, *@family.ancestors(name)].any? { record?(it) }

  def record?(name)
    Hashira::Smells::Descent.new(@types.select { it.to_s == name }).parent.join("::").match?(RECORD)
  end

  def plain?(type) = type.accept(Hashira::Analysis::Syntax::Body).to_a.compact.all? { shape?(it) }

  def shape?(node)
    node.is_a?(Prism::CallNode) && !node.block && SHAPES.include?(node.receiver ? :"self.#{node.name}" : node.name)
  end
end
