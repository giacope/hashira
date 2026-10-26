module Shop
  class Form
    attr_accessor :name, :email, :team, :role, :notes

    def summary = [name, email, team, role, notes].join(" ")
  end
end
