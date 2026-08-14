# frozen_string_literal: true

class Hashira::Smells::Kind
  def initialize(check)
    @check = check
  end

  def to_s = @check.name.split("::").last.gsub(/(?<=[a-z])(?=[A-Z])/, "_").downcase
end
