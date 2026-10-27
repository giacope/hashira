class BrowsePage < Tag
  def dependent_tags
    BrowsePage.all.to_a - [self]
  end

  def can_be_archived?
    published?
  end
end
