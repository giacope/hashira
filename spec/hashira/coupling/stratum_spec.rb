# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Stratum) do
  it "names the folder under app/ a file sits in" do
    paths = %w[app/controllers/concerns/authentication.rb /srv/app/app/models/order.rb /srv/app/models/app/order.rb]
    expect(paths.map { described_class.of(it) }).to(eq(%w[controllers models models]))
  end

  it "has no layer for a file outside an app/ folder or directly in it" do
    expect(%w[app/order.rb lib/billing/invoice.rb].map { described_class.of(it) }).to(eq([nil, nil]))
  end

  it "counts controllers, serializers and resources as presentation" do
    paths = %w[controllers serializers resources models jobs].map { "app/#{it}/x.rb" }
    expect(paths.map { described_class.presentation?(it) }).to(eq([true, true, true, false, false]))
  end
end
