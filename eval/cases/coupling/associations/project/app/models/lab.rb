class Lab < ApplicationRecord
  has_many :analyses
  has_many :cacti
end
