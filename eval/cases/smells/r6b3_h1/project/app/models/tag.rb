class Tag < ApplicationRecord
  belongs_to :parent, class_name: "Tag"

  def root?
    parent_id.blank?
  end

  def sort_mode
    root? ? :none : :curated
  end

  def level
    root? ? 1 : 2
  end

  def nested?
    parent.present?
  end

  def title_with_parent
    nested? ? "#{parent.title} / #{title}" : title
  end

  def full_slug
    [parent&.slug, slug].compact.join("/")
  end
end
