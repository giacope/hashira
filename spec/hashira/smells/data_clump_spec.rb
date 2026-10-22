# frozen_string_literal: true

RSpec.describe(Hashira::Smells::DataClump, :aggregate_failures) do
  def clumped(source) = sniffed({ "lib/app/zone/thing.rb" => source }, "data_clump")
  it "flags a parameter group that travels through three or more methods" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo, charlie, delta) = @a.use(alfa, bravo, charlie, delta)

            def two(alfa, bravo, charlie, echo) = @a.use(alfa, bravo, charlie, echo)

            def three(charlie, bravo, alfa) = one(alfa, bravo, charlie, @c)

            def four(echo) = @a.use(echo)
          end
        end
      end
    RUBY
    expect(findings.map { [it.package, it.evidence] })
      .to(eq([["App::Zone::Thing", ["(alfa, bravo, charlie) → 3 methods: one, two, three"]]]))
    expect(message(findings.first)).to(include("passes the same parameters", "zone/thing.rb:3"))
  end

  it "counts keyword parameters and ignores singleton methods" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa:, bravo:, charlie:) = @a.use(alfa, bravo, charlie)

            def two(alfa:, bravo:, charlie:) = @a.use(alfa, bravo, charlie)

            def three(alfa:, bravo:, charlie:) = one(alfa:, bravo:, charlie:)

            def self.four(alfa, bravo, charlie) = new(alfa, bravo, charlie)
          end
        end
      end
    RUBY
    expect(findings.first.evidence).to(eq(["(alfa, bravo, charlie) → 3 methods: one, two, three"]))
  end

  it "ignores block parameters but counts destructured components" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo, &blk) = @a.use(alfa, bravo, blk)

            def two(alfa, bravo, &blk) = @a.use(alfa, bravo, blk)

            def three(alfa, bravo, &blk) = one(alfa, bravo, &blk)

            def four((echo, foxtrot, golf)) = @a.use(echo, foxtrot, golf)

            def five(echo, foxtrot, golf) = @a.use(echo, foxtrot, golf)

            def six(echo, foxtrot, golf) = self.five(echo, foxtrot, golf)
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(eq(["(echo, foxtrot, golf) → 3 methods: four, five, six"]))
  end

  it "needs at least three shared names in at least three methods, so a pair handed on is no clump" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo, charlie) = @a.use(alfa, bravo, charlie)

            def two(alfa, bravo, charlie) = one(alfa, bravo, charlie)

            def three(alfa, bravo, delta) = one(alfa, bravo, delta)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "lists only the widest clumps, not every smaller set inside them" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(alfa, bravo, charlie, delta) = @a.use(alfa, bravo, charlie, delta)

            def two(alfa, bravo, charlie, delta) = @a.use(alfa, bravo, charlie, delta)

            def three(alfa, bravo, charlie, delta) = one(alfa, bravo, charlie, delta)

            def four(alfa, bravo, charlie) = @a.use(alfa, bravo, charlie)

            def five(echo, foxtrot, golf) = @a.use(echo, foxtrot, golf)

            def six(echo, foxtrot, golf) = @a.use(echo, foxtrot, golf)

            def seven(echo, foxtrot, golf) = five(echo, foxtrot, golf)
          end
        end
      end
    RUBY
    expect(findings.flat_map(&:evidence)).to(
      eq(
        [
          "(alfa, bravo, charlie, delta) → 3 methods: one, two, three",
          "(echo, foxtrot, golf) → 3 methods: five, six, seven"
        ]
      )
    )
  end

  it "judges a reopened class once, across every file that opens it" do
    findings = sniffed(
      {
        "lib/app/zone/thing.rb" => "class Thing\n  def one(alfa, bravo, charlie) = [alfa, bravo, charlie]\nend\n",
        "lib/app/zone/thing/two.rb" => "class Thing\n  def two(alfa, bravo, charlie) = [alfa, bravo, charlie]\nend\n",
        "lib/app/zone/thing/three.rb" => "class Thing\n  def three(alfa, bravo, charlie) = " \
          "one(alfa, bravo, charlie)\nend\n"
      },
      "data_clump"
    )
    expect(findings.size).to(eq(1))
    expect(findings.first.evidence).to(eq(["(alfa, bravo, charlie) → 3 methods: one, three, two"]))
  end

  it "drops underscore-prefixed and defaulted parameters from the group" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Thing
            def one(resource, scope, _content, as_of = @as_of) = @a.use(resource, scope, as_of)

            def two(resource, scope, _content, as_of = @as_of) = @a.use(resource, scope, as_of)

            def three(resource, scope, _content, as_of: @as_of) = one(resource, scope, _content, as_of)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "skips methods that fill a role a related class defines too, as every driver behind one port does" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Port
            def create(resource, name, mode) = raise(NotImplementedError)

            def destroy(resource, name, mode) = raise(NotImplementedError)

            def rename(resource, name, mode) = create(resource, name, mode)
          end

          class Disk < Port
            def create(resource, name, mode) = @disk.touch(resource, name, mode)

            def destroy(resource, name, mode) = @disk.rm(resource, name, mode)

            def rename(resource, name, mode) = create(resource, name, mode)
          end
        end
      end
    RUBY
    expect(findings).to(be_empty)
  end

  it "needs one holder to hand the group on to another, not just share a signature convention" do
    findings = clumped(<<~RUBY)
      module App
        module Zone
          class Client
            def get(path, body, headers) = @http.call(:get, path, body, headers)

            def post(path, body, headers) = @tries.zero? ? @http.post(path, body, headers) : post(path, body, headers)

            def patch(path, body, headers)
              get
              @http.patch(path, body, headers)
            end
          end

          class Relay
            def get(path, body, headers) = @http.call(:get, path, body, headers)

            def post(path, body, headers) = @http.call(:post, path, body, headers)

            def patch(path, body, headers) = post(path, body, headers)
          end
        end
      end
    RUBY
    expect(findings.map(&:package)).to(eq(["App::Zone::Relay"]))
  end
end
