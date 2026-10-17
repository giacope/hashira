# frozen_string_literal: true

RSpec.describe(Hashira::Smells::DataClass) do
  def bags(source, extra = "") = sniffed({ "lib/app/point.rb" => source, "lib/app/more.rb" => extra }, "data_class")

  def point(body = "") = <<~RUBY
    module App
      class Point
        attr_accessor :x, :y

        def initialize(x, y = nil)
          @x = x
          @y = y
        end
        #{body}
      end
    end
  RUBY

  it "flags a class of attributes and nothing else, naming the fields" do
    finding = bags(point).first
    expect(
      [
        finding.package, finding.detail,
        finding.evidence
      ]
    ).to(eq(["App::Point", { site: "point.rb:2", fields: %w[x y] }, %w[x y]]))
  end

  it "says what the class holds and what to do" do
    said = "App::Point holds 'x', 'y' and does nothing else (point.rb:2). " \
      "Move the code that works on these fields into the class, or declare it a Data value."
    expect(message(bags(point).first)).to(eq(said))
  end

  it "counts hand-written readers and writers, visibility markers and fields only the constructor stores" do
    accessors = [
      "def z = @z", "def z=(value)\n    @z = value\n  end", "private\n  def w = @w",
      "def initialize = @z = nil"
    ]
    expect(accessors.map { bags(point(it)).first.detail[:fields] }).to(eq([%w[x y], %w[x y z], %w[x y], %w[x y z]]))
  end

  it "leaves alone a class with behavior, a class method, a mixin, a constant, or a constructor that computes" do
    bodies = ["def norm = Math.sqrt(x**2)", "def self.origin = new(0, 0)", "include Comparable", "ORIGIN = 0"]
    computing = point.sub("@x = x", "@x = x.to_f")
    expect(bodies.map { bags(point(it)) } + [bags(computing)]).to(all(be_empty))
  end

  it "leaves alone a reader that does more than read, and a writer that does more than store" do
    bodies = ["def z = @z.to_s", "def z=(value)\n    @z = value\n    log(value)\n  end"]
    expect(bodies.map { bags(point(it)) }).to(all(be_empty))
  end

  it "reads a bare attribute macro as declaring nothing" do
    expect(bags(point("attr_reader")).first.detail[:fields]).to(eq(%w[x y]))
  end

  it "leaves alone a class with fewer than two fields" do
    expect(bags("module App\n  class Id\n    attr_reader :value\n  end\nend\n")).to(be_empty)
  end

  it "leaves alone a class with a superclass, a subclass, or behavior in another opening" do
    sources = [point.sub("class Point", "class Point < Base"), point.sub("class Point", "class Point < Struct.new(:z)")]
    others = [
      "module App\n  class Pixel < Point\n  end\nend\n",
      "module App\n  class Point\n    def norm = 1\n  end\nend\n"
    ]
    expect(sources.map { bags(it) } + others.map { bags(point, it) }).to(all(be_empty))
  end

  it "leaves modules alone" do
    expect(bags(point.sub("class Point", "module Point").sub(/  def initialize.*?end\n/m, ""))).to(be_empty)
  end
end
