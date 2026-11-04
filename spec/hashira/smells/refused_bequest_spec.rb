# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RefusedBequest, :aggregate_failures) do
  def refused(source) = sniffed({ "lib/app/store.rb" => source }, "refused_bequest")

  def stores(override, inherited = "def save(row) = @rows << row") = <<~RUBY
    module App
      class Store
        def initialize = @rows = []

        #{inherited}
      end

      class Archive < Store
        #{override}
      end
    end
  RUBY

  it "flags the inherited method a subclass overrides only to raise, naming the subclass and where" do
    finding = refused(stores("def save(row) = raise(NotImplementedError)")).first
    expect([finding.to_h[:package], finding.to_h[:detail], finding.to_h[:evidence]]).to(
      eq(
        [
          "App::Store#save", { site: "store.rb:5", places: 1, parent: "App::Store" },
          ["App::Archive raises (store.rb:9)"]
        ]
      )
    )
  end

  it "says what was refused and what to do" do
    said = "App::Store#save is overridden by a subclass only to raise or do nothing (store.rb:5). " \
      "Compose the parent instead of extending it, or move the refused methods to the subclasses that want them."
    expect(message(refused(stores("def save(row) = fail('read only')")).first)).to(eq(said))
  end

  it "flags an override that does nothing, whether empty or a bare nil" do
    bodies = ["def save(row); end", "def save(row) = nil", "def save(row)\n    nil\n  end"]
    expect(bodies.map { refused(stores(it)).first.to_h[:evidence] }).to(
      all(eq(["App::Archive does nothing (store.rb:9)"]))
    )
  end

  it "leaves an override alone that does something, or raises after doing something" do
    bodies = [
      "def save(row) = super", "def save(row) = log.fail(row)",
      "def save(row)\n    log(row)\n    raise 'no'\n  end"
    ]
    expect(bodies.map { refused(stores(it)) }).to(all(be_empty))
  end

  it "leaves alone a refusal of an inherited hook that itself does nothing or raises" do
    hooks = ["def save(row); end", "def save(row) = raise(NotImplementedError)"]
    expect(hooks.map { refused(stores("def save(row) = raise('no')", it)) }).to(all(be_empty))
  end

  it "leaves alone a method the parent never defined, a singleton method, and a foreign parent's" do
    foreign = stores("def save(row) = nil").sub("Archive < Store", "Archive < Base")
    sources = [stores("def load = nil"), stores("def self.save(row) = nil"), foreign]
    expect(sources.map { refused(it) }).to(all(be_empty))
  end

  it "weighs the nearest ancestor's definition: refusing what the parent already refused is the parent's finding" do
    grand = "module App\n  class Base\n    def save(row) = @rows << row\n  end\nend\n"
    source = stores("def save(row) = nil", "def save(row) = nil").sub("class Store\n", "class Store < Base\n")
    deep = stores("def load = nil").sub("class Store\n", "class Store < Base\n")
    expect([refused(grand + source), refused(grand + deep)].map { it.map { it.to_h[:evidence] } }).to(
      eq([[["App::Store does nothing (store.rb:10)"]], []])
    )
  end

  it "reaches past a parent to a grandparent's behavior" do
    grand = "module App\n  class Base\n    def drop(row) = @rows.delete(row)\n  end\nend\n"
    source = stores("def drop(row) = nil").sub("class Store\n", "class Store < Base\n")
    expect(refused(grand + source).map { [it.to_h[:package], it.to_h[:evidence]] }).to(
      eq([["App::Base#drop", ["App::Archive does nothing (store.rb:14)"]]])
    )
  end
end
