# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ModuleInitialize, :aggregate_failures) do
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
    expect(findings.map(&:package)).to(eq(["App::Zone::Mixin"]))
    expect(message(findings.first)).to(include("defines initialize in a module", "zone/thing.rb:3"))
  end

  it "flags a cooperative initialize that calls super, since it still carries constructor state" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            module Cooperative
              def initialize(*)
                super
                @ready = true
              end
            end
          end
        end
      RUBY
    }
    finding = sniffed(files, "module_initialize").first
    expect(message(finding)).to(include("implementation inheritance", "compose a collaborator"))
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

  it "leaves alone a library class a block reopens, and judges a module it reopens" do
    files = {
      "lib/app/patch.rb" => "Samovar::Output::Formatter.class_eval do\n  def initialize(rows) = @rows = rows\nend\n",
      "lib/app/mixin.rb" => "module App\n  module Mixin; end\n\n  Mixin.module_eval { def initialize = @x = 1 }\nend\n"
    }
    expect(sniffed(files, "module_initialize").map(&:package)).to(eq(["App::Mixin"]))
  end

  it "leaves alone a module that extends itself: no mixin, its initialize an ordinary method" do
    files = {
      "lib/app/zone/thing.rb" => <<~RUBY
        module App
          module Zone
            module Sync
              extend self

              def initialize = @client = Client.new
              def run = initialize && @client.pull
            end

            module Mixin
              extend Forwardable

              def initialize = @client = Client.new
            end
          end
        end
      RUBY
    }
    expect(sniffed(files, "module_initialize").map(&:package)).to(eq(["App::Zone::Mixin"]))
  end
end
