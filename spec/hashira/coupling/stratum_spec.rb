# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Stratum, :aggregate_failures) do
  it "reads the folder under app/ a file sits in" do
    paths = %w[app/controllers/concerns/authentication.rb /srv/app/app/models/order.rb /srv/app/models/app/order.rb]
    expect(paths.map { described_class.new(it).within?(%w[controllers]) }).to(eq([true, false, false]))
    expect(paths.map { described_class.new(it).within?(%w[models]) }).to(eq([false, true, true]))
  end

  it "has no layer for a file outside an app/ folder or directly in it" do
    expect(%w[app/order.rb lib/billing/invoice.rb].map { described_class.new(it).within?(%w[order.rb billing]) })
      .to(eq([false, false]))
  end

  it "counts controllers, serializers and resources as presentation, and no test" do
    paths = %w[controllers serializers resources models jobs].map { "app/#{it}/x.rb" }
    paths << "test/controllers/orders_controller_test.rb"
    expect(paths.map { described_class.new(it).presentation? }).to(eq([true, true, true, false, false, false]))
  end
end
