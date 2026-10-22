module Shop
  class User
    def adapter(name) = ADAPTERS.fetch(name)
    def session = Session.new(self)
  end
end
