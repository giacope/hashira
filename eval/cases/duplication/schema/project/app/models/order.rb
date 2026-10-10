class Order < ApplicationRecord
  belongs_to :customer
  belongs_to :store
  has_many :line_items, dependent: :destroy
  has_many :adjustments, dependent: :destroy
  validates :number, presence: true, uniqueness: true
  validates :currency, presence: true
  scope :recent, -> { order(created_at: :desc) }
end
