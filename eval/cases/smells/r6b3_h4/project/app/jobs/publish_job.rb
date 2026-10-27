class PublishJob
  include Sidekiq::Job

  def perform(tag_id)
    Tag.find(tag_id).publish
  end
end
