# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ModuleInitialize) do
  it "flags initialize defined in a module and leaves classes alone" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            module Mixin
              def initialize
                @x = 1
              end
            end

            class Thing
              def initialize
                @x = 1
              end
            end

            module Clean
              def self.initialize = nil

              def helper = 1
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "module_initialize")
    expect(findings.size).to(eq(1))
    expect(findings.first.package).to(eq("App::Zone::Mixin"))
    expect(message(findings.first)).to(include("defines initialize in a module", "zone/thing.rb:3"))
  end
  it "flags block-born initializers but not those owned by an assigned constant" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            module Mixin
              included do
                def initialize
                  @x = 1
                end
              end
            end

            module Clean
              Value = Data.define(:a) do
                def initialize(a: 1) = super
              end
            end
          end
        end
      RUBY
    }
    findings = sniffed(files, "module_initialize")
    expect(findings.map(&:package)).to(eq(["App::Zone::Mixin"]))
  end
end
