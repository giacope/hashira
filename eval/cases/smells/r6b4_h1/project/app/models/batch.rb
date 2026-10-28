class Batch < ApplicationRecord
  has_many :entries

  def finished?
    %w[succeeded failed].include?(state)
  end

  def succeeded?
    state == "succeeded"
  end

  def failed?
    state == "failed"
  end

  def process
    tracking do
      entries.each(&:apply)
    end
  end

  def pending
    entries.reject(&:done?)
  end

  def tracking
    return if self.state == "processing"
    update_column(:state, "processing")
    yield
    self.state = "succeeded"
    save!
  end
end
