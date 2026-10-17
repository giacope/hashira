# frozen_string_literal: true

RSpec.describe(Hashira::Smells::RefusedBequest) do
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

  it "flags a subclass that overrides an inherited method only to raise, naming the method and its owner" do
    finding = refused(stores("def save(row) = raise(NotImplementedError)")).first
    expect([finding.package, finding.detail, finding.evidence]).to(
      eq(["App::Archive", { site: "store.rb:8", parent: "App::Store", names: ["save"] }, ["save raises (line 9, over App::Store)"]])
    )
  end

  it "says what was refused and what to do" do
    said = "App::Archive overrides 'save' of App::Store only to raise or do nothing (store.rb:8). " \
      "Compose the parent instead of extending it, or move the refused methods to the subclasses that want them."
    expect(message(refused(stores("def save(row) = fail('read only')")).first)).to(eq(said))
  end

  it "flags an override that does nothing, whether empty or a bare nil" do
    bodies = ["def save(row); end", "def save(row) = nil", "def save(row)\n    nil\n  end"]
    expect(bodies.map { refused(stores(it)).first.evidence.first }).to(all(start_with("save does nothing (line 9")))
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
    expect([refused(grand + source), refused(grand + deep)].map { it.map(&:package) }).to(eq([["App::Store"], []]))
  end

  it "reaches past a parent to a grandparent's behavior" do
    grand = "module App\n  class Base\n    def drop(row) = @rows.delete(row)\n  end\nend\n"
    source = stores("def drop(row) = nil").sub("class Store\n", "class Store < Base\n")
    expect(refused(grand + source).first.evidence).to(eq(["drop does nothing (line 14, over App::Base)"]))
  end
end
