class ListPublisher
  def initialize(tag)
    @tag = tag
  end

  def perform
    @tag.lists.each(&:publish)
  end
end
