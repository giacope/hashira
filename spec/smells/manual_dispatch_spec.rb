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
    expect(message(findings.first)).to(include("dispatches manually via respond_to?", "zone/thing.rb:5, 6"))
  end

  it "flags a bare capability check, but not the respond_to_missing? that method_missing obliges" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            class Thing
              def method_missing(name, *) = @target.respond_to?(name) ? @target.public_send(name, *) : super

              def respond_to_missing?(name, all = false) = @target.respond_to?(name, all) || super

              def probe(duck) = duck.respond_to?(:honk)
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "manual_dispatch").map(&:package)).to(
      eq(%w[App::Zone::Thing#method_missing App::Zone::Thing#probe])
    )
  end
end
