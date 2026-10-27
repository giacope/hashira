module Shop
  class QueueJob < Shop.parent_job.constantize
    def perform(name, inline)
      if inline
        Shop::IndexJob.new.perform(name)
      else
        Shop::IndexJob.perform_later(name)
      end
    end
  end
end
