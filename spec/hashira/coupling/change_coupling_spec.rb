# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::ChangeCoupling, :aggregate_failures) do
  def commit(touched)
    touched.each { |path| File.write(path, "#{File.read(path)}# #{rand}\n") }
    git("add", *touched)
    git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", "change")
  end

  def files
    {
      "lib/app/a/x.rb" => "# frozen\n\nmodule App; module A; class X; def y = [B::Y, X]; end; end; end",
      "lib/app/a/v.rb" => "module App; module A; class V; end; end; end\n",
      "lib/app/b/y.rb" => "module App; module B; class Y; end; end; end\n",
      "lib/app/c/z.rb" => "module App; module C; class Z; end; end; end\n",
      "lib/app/d/p.rb" => "", "lib/app/e/q.rb" => "module App; module E; class Q; end; end; end\n"
    }
  end

  def history
    git("init", "-q")
    5.times { commit(%w[lib/app/a/x.rb lib/app/b/y.rb]) }
    5.times { commit(%w[lib/app/a/x.rb lib/app/a/v.rb]) }
    5.times { commit(%w[lib/app/d/p.rb lib/app/e/q.rb]) }
    3.times { commit(%w[lib/app/e/q.rb]) }
    4.times { commit(%w[lib/app/c/z.rb lib/app/e/q.rb]) }
  end

  def coupled(*raws)
    within(files) do
      history
      return (raws.empty? ? [true] : raws).map { found(it) }
    end
  end

  def found(raw, directories = ["lib/app"])
    rules = Hashira::Config::Rules.parse({ "change_coupling" => raw }, Hashira::Pipeline::KINDS)
    Hashira::Pipeline.new(Hashira::Project.new(directories, rules:)).findings.select { it.kind == "change_coupling" }
  end

  def cut
    history
    git("clone", "-q", "--depth", "20", "file://#{Dir.pwd}", "cut")
    rules = Hashira::Config::Rules.parse({ "change_coupling" => true }, Hashira::Pipeline::KINDS)
    Dir.chdir("cut") do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules:))
      [found(true), pipeline.checks?("change_coupling"), pipeline.checks?("dead_code")]
    end
  end

  it "judges nothing in a shallow clone, which holds only the commits it was cut at, and leaves it out of the gate" do
    expect(within(files) { cut }).to(eq([[], false, true]))
  end

  it "pairs files in two packages that change together in most of their commits" do
    expect(coupled.first.map { [it.digest, it.detail.shared, it.detail.degree, it.anchors] }).to(
      eq([["a/x.rb <-> b/y.rb", 5, 67, %w[a/x.rb:3 b/y.rb:1]], ["d/p.rb <-> e/q.rb", 5, 59, %w[d/p.rb:1 e/q.rb:1]]])
    )
  end

  it "says how often they changed together, and whether one refers to the other" do
    said = coupled.first.map { message(it)[/, (?:and|though) [^—]*/] }
    expect(said).to(eq([", and one refers to the other ", ", though neither refers to the other "]))
  end

  def registered(source)
    within(files.merge("lib/app/d/p.rb" => source)) do
      history
      return found(true).map(&:digest)
    end
  end

  it "leaves out a pair where one file only loads the other, or lists its path, as a registration" do
    named = [
      "require_relative \"../e/q\"\n", "require \"app/e/q\"\n", "load \"e/q.rb\"\n", "FILES = %w[app/e/q.rb].freeze\n"
    ]
    apart = ["require\nrequire_relative \"../c/z\"\nrequire_relative \"e/q\"\n", "NAME = \"e/q\"\n"]
    used = "require_relative \"../e/q\"\nmodule App; module D; class P; def q = E::Q; end; end; end\n"
    expect((named + apart + [used]).map { registered(it).size }).to(eq([1, 1, 1, 1, 2, 2, 2]))
  end

  it "moves the commits, the share and the size of a commit worth counting" do
    limits = coupled({ "commits" => 6 }, { "degree" => 67 }, { "files" => 1 }).map { it.map(&:digest) }
    expect(limits).to(eq([[], ["a/x.rb <-> b/y.rb"], []]))
  end

  def rails
    {
      "config/application.rb" => "module Shop\n  class Application < Rails::Application\n  end\nend\n",
      "app/models/order.rb" => "class Order\n  def total = 1\nend\n",
      "app/models/invoice.rb" => "class Invoice\n  def due = 1\nend\n",
      "app/policies/order_policy.rb" => "class OrderPolicy\n  def show? = true\nend\n"
    }
  end

  def namespaced
    within(rails) do
      git("init", "-q")
      5.times { commit(%w[app/models/order.rb app/models/invoice.rb app/policies/order_policy.rb]) }
      return found(true, ["app"]).map { it.detail.packages }
    end
  end

  it "pairs files by the namespace packages their types join in a Rails app, folds included" do
    expect(namespaced).to(eq([%w[Invoice Order], %w[Invoice Order]]))
  end

  def tied
    within(files) do
      git("init", "-q")
      5.times { commit(%w[lib/app/a/v.rb lib/app/b/y.rb]) }
      5.times { commit(%w[lib/app/d/p.rb lib/app/e/q.rb]) }
      return found(true).map(&:digest)
    end
  end

  it "lists pairs as strong as each other by their files" do
    expect(tied).to(eq(["a/v.rb <-> b/y.rb", "d/p.rb <-> e/q.rb"]))
  end
end
