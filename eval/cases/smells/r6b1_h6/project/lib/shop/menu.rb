module Shop
  class Menu
    include Enumerable

    def initialize(user)
      @entries = [Shop::HelpEntry.new(user), Shop::OrdersEntry.new(user)]
    end

    def each(&) = @entries.select(&:visible?).each(&)
  end
end
