module Shop
  class HelpEntry
    def initialize(user)
      @user = user
    end

    def label = "Help"

    def link
      Shop.routes.help_path
    end

    def visible? = @user.signed_in?

    def hint = Shop.routes.hint_path
  end
end
