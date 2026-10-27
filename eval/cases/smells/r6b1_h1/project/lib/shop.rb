module Shop
  def self.parent_job = "ActiveJob::Base"
  def self.model_parent = "ActiveRecord::Base"
  def self.load(name) = Object.const_get(name)
end
