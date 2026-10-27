module Shop
  class OrdersEntry
    def initialize(user)
      @user = user
    end

    def label = "Orders"

    def link
      Shop.routes.orders_path(@user.id)
    end

    def visible? = @user.admin?
  end
end
