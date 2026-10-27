# frozen_string_literal: true

require "digest"

module Shop
  class Vault
    def initialize(entries) = @entries = entries

    def hash(password) = Digest::SHA256.hexdigest(password)

    def size = @entries.size
  end
end
