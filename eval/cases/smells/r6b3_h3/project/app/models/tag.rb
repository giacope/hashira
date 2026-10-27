class Tag < ApplicationRecord
  def full_slug
    [parent_slug, slug].compact.join("/")
  end

  def dependent_tags
    Tag.where(parent_id: id).to_a
  end

  def can_be_archived?
    raise NoMethodError
  end
end
