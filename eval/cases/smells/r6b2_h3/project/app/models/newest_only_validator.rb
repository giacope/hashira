# frozen_string_literal: true

class NewestOnlyValidator < ActiveModel::Validator
  def validate(record)
    record.errors.add(:base, "Only the newest set can change.") unless record.newest?
  end

  def report(record) = record.errors.full_messages.join(", ")
end
