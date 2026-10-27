class Place < ApplicationRecord
  validates_with NewestOnlyValidator, on: :update

  def newest? = data_set.latest?

  def import!
    save!(validate: false)
  end
end
