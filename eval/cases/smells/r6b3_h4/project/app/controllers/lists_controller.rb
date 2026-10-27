class ListsController
  def initialize(tag)
    @tag = tag
  end

  def publish
    ListPublisher.new(@tag).perform
  end
end
