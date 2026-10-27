module Shop
  class ApplicationRecord < Shop.model_parent.constantize
    self.abstract_class = true
  end
end
