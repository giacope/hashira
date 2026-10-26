module Shop
  class Formatter
    def money(cents) = cents.fdiv(100).round(2)
  end
end
