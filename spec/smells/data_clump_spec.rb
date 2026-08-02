# frozen_string_literal: true

RSpec.describe(Hashira::Smells::DataClump) do
  def clumped(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "data_clump")
  it "flags a parameter pair that travels through three or more methods" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo, charlie) = @a.use(alfa, bravo, charlie)

            def two(alfa, bravo, delta) = @a.use(alfa, bravo, delta)

            def three(bravo, alfa) = @a.use(alfa, bravo)

            def four(echo) = @a.use(echo)
          end
        end
      end
    RUBY
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("App::Zone::Thing"))
    expect(finding.message).to(include("passes the same parameters", "zone/thing.rb:3"))
    expect(finding.evidence).to(eq(["(alfa, bravo) → 3 methods: one, two, three"]))
  end
  it "counts keyword parameters and ignores singleton methods" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa:, bravo: 1) = @a.use(alfa, bravo)

            def two(alfa:, bravo: 2) = @a.use(alfa, bravo)

            def three(alfa:, bravo: 3) = @a.use(alfa, bravo)

            def self.four(alfa, bravo) = new(alfa, bravo)
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["(alfa, bravo) → 3 methods: one, two, three"]))
  end
  it "ignores block parameters but counts destructured components" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, &blk) = @a.use(alfa, blk)

            def two(alfa, &blk) = @a.use(alfa, blk)

            def three(alfa, &blk) = @a.use(alfa, blk)

            def four((echo, foxtrot)) = @a.use(echo, foxtrot)

            def five(echo, foxtrot) = @a.use(echo, foxtrot)

            def six(echo, foxtrot) = @a.use(echo, foxtrot)
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["(echo, foxtrot) → 3 methods: four, five, six"]))
  end
  it "needs at least two shared names in at least three methods" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo) = @a.use(alfa, bravo)

            def two(alfa, bravo) = @a.use(alfa, bravo)

            def three(alfa, charlie) = @a.use(alfa, charlie)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end
end
