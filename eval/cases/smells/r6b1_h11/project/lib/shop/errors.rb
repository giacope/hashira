module Shop
  class Error < StandardError; end

  class AuthError < Error
    def message
      I18n.t("shop.errors.auth")
    end

    def hint
      I18n.t("shop.errors.hint")
    end
  end
end
