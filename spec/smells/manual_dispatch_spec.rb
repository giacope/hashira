# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ManualDispatch) do
  it "flags respond_to? probes and lists every probing line" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Thing
              def poke(duck)
                duck.honk if duck.respond_to?(:honk)
                duck.moo if duck.respond_to?(:moo)
              end

              def plain(duck) = duck.honk
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "manual_dispatch")
    expect(findings.size).to(eq(1))
    expect(findings.first.package).to(eq("App::Zone::Thing#poke"))
    expect(findings.first.message).to(include("dispatches manually via respond_to?", "zone/thing.rb:5, 6"))
  end
end
