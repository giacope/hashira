# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Check, :aggregate_failures) do
  it "names a finding without evidence by the shape of its code, and one with evidence by its evidence alone" do
    cart = <<~RUBY
      module App
        class Cart
          def price(item) = item.amount.round
          def total(quick) = quick ? @a : @b
        end
      end
    RUBY
    files = { "lib/app/cart.rb" => cart, "lib/app/till.rb" => "class Till\n  def run = App::Cart.new.total(true)\nend\n" }
    found = %w[utility_function control_parameter].map { sniffed(files, it).first }
    told = found.map { [it.to_h[:evidence].empty?, mark_of(it).trace.split("|").last] }
    expect(told).to(match([[true, match(/\A\h{12}\z/)], [false, "quick"]]))
  end
end
