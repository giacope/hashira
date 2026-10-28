require "active_support"

module Shop
  class DuplicateError < StandardError
  end

  def self.setup = @setup ||= true
end

ActiveSupport.on_load(:active_record) do
  extend Shop::Taggable
end
