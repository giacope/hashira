require "forwardable"

module Shop
  module Registry
    extend Forwardable

    def_delegator :entries, :size, :count

    def entries
      @entries ||= {}
    end

    def lookup(key)
      @entries.fetch(key) { "none" }
    end
  end
end
