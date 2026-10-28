module Broadcastable
  extend ActiveSupport::Concern

  included do
    thread_mattr_accessor :suppressed_broadcasts, instance_accessor: false
    delegate :suppressed_broadcasts?, to: "self.class"
  end

  def broadcast_remove
    Channel.remove(self) unless suppressed_broadcasts?
  end
end
