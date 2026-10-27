module Shop
  class IndexJob < Shop.parent_job.constantize
    def perform(name)
      Shop.load(name).reindex
    end
  end
end
