# frozen_string_literal: true

RSpec.describe(Hashira::Smells::NilCheck) do
  def checked(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "nil_check")
  it "flags nil?, nil comparisons, and when-nil clauses with their lines" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def query(x) = x.nil? && @a

            def compare(x) = x == nil || nil == x

            def strict(x) = x === nil

            def branch(x)
              case x
              when nil then @a
              else @b
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(
      eq(%w[App::Zone::Thing#query App::Zone::Thing#compare App::Zone::Thing#strict App::Zone::Thing#branch])
    )
    expect(message(findings.first)).to(include("checks for nil", "zone/thing.rb:4"))
  end

  it "reaches methods defined inside blocks and class << self" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            concerning :Checks do
              def check = @a.nil?
            end

            class << self
              def peek = @cache.nil?
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Thing#check", "App::Zone::Thing.peek"]))
  end

  it "advises translating at the boundary when the nil-checked value arrives from outside" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def keyed(params) = params[:name].nil?

            def header(request)
              token = request.headers["X-Token"]
              token.nil?
            end

            def parsed(body)
              data = JSON.parse(body)
              case data
              when nil then @a
              end
            end

            def mixed(params) = params["id"] == nil || @cache.nil?
          end
        end
      end
    RUBY
    expect(findings.map { it.detail[:origin] }).to(eq(%i[outside outside outside both]))
    expect(message(findings.first)).to(include("comes from outside", "where it enters, at the boundary"))
    expect(message(findings.last)).to(include("where it enters; elsewhere prefer a null object"))
  end

  it "keeps the null-object advice for values the method made or was handed" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def built
              result = { id: nil }
              result[:id].nil?
            end

            def handed(value) = value.nil?

            def mine = nil?

            def owned
              record = Thing.find(1)
              record.nil?
            end

            def blind
              case
              when nil then @a
              end
            end
          end
        end
      end
    RUBY
    expect(findings.map(&:detail).uniq(&:keys).map(&:keys)).to(eq([[:site]]))
    expect(findings.size).to(eq(5))
  end

  it "ignores comparisons that never involve nil" do
    findings = checked(<<~RUBY)
      module App
        module Zone
          class Thing
            def fine(x)
              case x
              when :a then @a
              else x == :b ? @b : @c
              end
            end

            def odd(x) = x.==
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
