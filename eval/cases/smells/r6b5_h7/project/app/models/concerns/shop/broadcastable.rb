module Shop::Broadcastable
  extend ActiveSupport::Concern

  module ClassMethods
    def broadcasts_refreshes_to(stream)
      after_commit -> { broadcast_refresh_to(stream) }
    end
  end

  def broadcast_refresh_to(stream)
    Shop::Channel.deliver(stream, self)
  end

  def broadcast_later_to(stream)
    Shop::Channel.deliver_later(stream, self)
  end
end
