class Account < ApplicationRecord
  belongs_to :owner

  def debt = balance.negative? ? -balance : 0
  def credit = balance.positive? ? balance : 0
  def overdrawn? = balance < -100
  def domain = owner_id.to_s + email.split("@").last
  def masked = email.sub(/\A[^@]+/, "***")
  def corporate? = domain != "gmail.com"
end
