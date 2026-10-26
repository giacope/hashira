module Shop
  class PurgeJob < Shop.parent_job.constantize
    def perform(name)
      Shop.load(name).purge
    end
  end
end
