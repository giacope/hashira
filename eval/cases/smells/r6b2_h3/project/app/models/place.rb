# frozen_string_literal: true

class Place < ApplicationRecord
  validates_with NewestOnlyValidator, on: :update
  validate :coordinates_paired

  def newest? = data_set.latest?

  def problems = NewestOnlyValidator.new.report(self)

  private

  def coordinates_paired
    errors.add(:lat, "needs lng") if lat && !lng
  end
end
