class NewestOnlyValidator < ActiveModel::Validator
  def validate(record)
    record.errors.add(:base, "Only the newest set can change.") unless record.newest?
  end
end
