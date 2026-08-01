# frozen_string_literal: true

require_relative "placement"

class Hashira::Analysis::NamespacePlacement < Hashira::Analysis::Placement
  RAILS_BASES =
    %w[ApplicationRecord ApplicationController ApplicationJob ApplicationMailer
      ApplicationHelper ApplicationCable ApplicationResource ApplicationSerializer
      ApplicationPolicy ApplicationDecorator].freeze

  def mode = :namespace

  def placed = catalog.map { [it, it.name] }

  def baseline = []

  def charge(_file, nesting)
    nesting.reverse_each.filter_map { catalog.strip(it).first }.first || project.root
  end

  def skip?(segments) = project.rails? && RAILS_BASES.include?(segments.first)

  def folding(census) = Hashira::Analysis::Folding.new(catalog, census, suffixes: suffixes)

  private

  def suffixes = project.rails? ? Hashira::Analysis::Folding::SUFFIXES : []
end
