class Post < ApplicationRecord
  belongs_to :author
  has_and_belongs_to_many :categories
  has_many :comments, class_name: "Remark"
  has_many :statuses
end
