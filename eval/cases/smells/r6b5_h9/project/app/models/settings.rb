module Settings
  mattr_accessor :batch_size
  self.batch_size = 1000

  def self.config = yield(self)
end
