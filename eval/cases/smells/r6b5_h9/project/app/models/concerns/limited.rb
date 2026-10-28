module Limited
  extend ActiveSupport::Concern

  included do
    cattr_accessor :limit
  end
end
