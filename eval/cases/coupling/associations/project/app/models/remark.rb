class Remark < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end
