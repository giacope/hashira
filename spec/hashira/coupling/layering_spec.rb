# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Layering, :aggregate_failures) do
  def type(space, name, body) = "module App; module #{space}; class #{name}; #{body}; end; end; end\n"

  def files
    {
      "lib/app/web/page.rb" => type("Web", "Page", "def a = [Domain::Order, Domain::Order]"),
      "lib/app/jobs/run.rb" => type("Jobs", "Run", "def go = [Domain::Order, Comparable]"),
      "lib/app/domain/order.rb" => <<~RUBY
        module App
          module Domain
            class Order
              def page = Web::Page.new
              def again = Web::Page
              def run = Jobs::Run
            end
          end
        end
      RUBY
    }
  end

  def layered(declared, extra = {}, base = files)
    within(base.merge(extra)) do
      rules = Hashira::Config::Rules::NONE.layered(Hashira::Config::Layers.parse(declared))
      return Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules:)).screened.kept.select { it.kind == "layer_violation" }
    end
  end

  def summary(findings) = findings.map { [it.digest, it.detail.refs, it.detail.cut, it.evidence.size] }

  def edge(from, to, weight) = { from:, to:, weight: }

  it "reports each inner layer's references to an outer one, with the class edges to cut, cheapest first" do
    expect(summary(layered(%w[web jobs domain]))).to(
      eq(
        [
          ["domain -> web", 2, [edge("Domain::Order", "Web::Page", 2)], 2],
          ["domain -> jobs", 1, [edge("Domain::Order", "Jobs::Run", 1)], 1]
        ]
      )
    )
  end

  it "says what depends on what, and what to cut" do
    said = "domain depends on web, an outer layer, through 2 refs — a layer may depend only on the layers declared " \
      "inside it. Cut Domain::Order -> Web::Page (2 refs)."
    expect(message(layered(%w[web jobs domain]).first)).to(eq(said))
  end

  it "leaves references within a layer, files in no layer, and a project without layers alone" do
    expect([layered([{ "all" => %w[web jobs domain] }, "rest"]), layered(%w[nothing here]), layered(nil)])
      .to(eq([[], [], []]))
  end

  it "places a constant by the paths that define it, and skips one defined in two layers" do
    reopened = { "lib/app/jobs/page.rb" => type("Web", "Page", "def x = 1") }
    paths = [{ "outer" => "lib/app/web" }, { "middle" => "lib/app/jobs" }, { "inner" => "lib/app/domain" }]
    expect([layered(paths), layered(paths, reopened)].map { |found| found.map { [it.digest, it.detail.refs] } })
      .to(eq([[["inner -> outer", 2], ["inner -> middle", 1]], [["inner -> middle", 1]]]))
  end

  it "lists a pair's edges by weight" do
    linked = { "lib/app/jobs/link.rb" => type("Jobs", "Link", "def x = Web::Page") }
    expect(layered(["web", { "inner" => %w[domain jobs] }], linked).first.detail.cut)
      .to(eq([edge("Jobs::Link", "Web::Page", 1), edge("Domain::Order", "Web::Page", 2)]))
  end

  it "names the classes at each end of an edge, not the package they share, nor a file's or the namespace's code" do
    split = {
      "lib/app/web/core.rb" => type("Web", "Core", "def x = Web::Page"),
      "lib/app/domain/boot.rb" => "App::Web::Page.new\n",
      "lib/app/domain/wiring.rb" => "module App\n  PAGE = Web::Page\nend\n"
    }
    layers = [{ "outer" => %w[lib/app/web/page.rb] }, { "inner" => %w[lib/app/web/core.rb lib/app/domain] }]
    expect(layered(layers, split).first.detail.cut).to(
      eq(
        [
          edge("App", "Web::Page", 1), edge("Web::Core", "Web::Page", 1), edge("domain/boot.rb", "Web::Page", 1),
          edge("Domain::Order", "Web::Page", 2)
        ]
      )
    )
  end

  def rails
    {
      "config/application.rb" => "module Shop\n  class Application < Rails::Application\n  end\nend\n",
      "app/models/invoice.rb" => "class Invoice\n  def due = 1\nend\n",
      "app/policies/invoice_policy.rb" => "class InvoicePolicy\n  def show? = true\nend\n",
      "app/controllers/invoices_controller.rb" => "class InvoicesController\n  def show = [Invoice, InvoicePolicy]\nend"
    }
  end

  def namespaced
    within(rails) do
      rules = Hashira::Config::Rules::NONE.layered(Hashira::Config::Layers.parse([{ "domain" => "Invoice" }, "(web)"]))
      return Hashira::Pipeline.new(Hashira::Project.new(["app"], rules:)).findings.select { it.kind == "layer_violation" }
    end
  end

  it "places a type by the namespace package it joins in a Rails app, folds included" do
    expect(namespaced.map { it.detail.cut })
      .to(eq([[edge("InvoicesController", "Invoice", 1), edge("InvoicesController", "InvoicePolicy", 1)]]))
  end

  it "names a constant two packages claim by its class" do
    shared = { "lib/app/extra/page.rb" => type("Web", "Page", "def y = 2") }
    layers = [{ "outer" => %w[web extra] }, { "inner" => %w[domain jobs] }]
    expect(layered(layers, shared).first.detail.cut).to(eq([edge("Domain::Order", "Web::Page", 2)]))
  end

  def more = { "lib/app/domain/more.rb" => type("Domain", "More", "def x = [Web::Page, Web::Page]") }

  def leaning = "The code leans another way: layered domain, web, only 2 refs would point outward — check the order."

  it "notes when the code leans the other way" do
    said = message(layered(%w[web domain], more).first)
    cut = "Cut Domain::More -> Web::Page (2 refs) and Domain::Order -> Web::Page (2 refs)."
    expect(said[/Cut .*/].sub("declared order", "order")).to(eq("#{cut} #{leaning}"))
  end

  it "keeps the declared order among the layers the references leave free" do
    upward = {
      "lib/app/web/page.rb" => type("Web", "Page", "def a = 1"),
      "lib/app/billing/run.rb" => type("Billing", "Run", "def go = Web::Page"),
      "lib/app/domain/order.rb" => type("Domain", "Order", "def page = Web::Page")
    }
    said = message(layered(%w[web billing domain], {}, upward).first)
    order = "layered billing, domain, web, no ref would point outward — check the declared order."
    expect(said[/layered .*/]).to(eq(order))
  end

  def long
    edges = (1..7).map { edge("p#{it}", "web", it) }
    detail = described_class::Detail.new(inner: "core", outer: "web", cut: edges, refs: 28, leaning: %w[core web])
      .with(against: 0)
    message(Hashira::Analysis::Finding.new(kind: "layer_violation", package: "core", evidence: [], detail:))
  end

  it "lists the edges to cut, the cheapest first, past a long list" do
    said = "p6 -> web (6 refs) and 1 more edge. The code leans another way: layered core, web, no ref"
    expect(long[/p6.*no ref/]).to(eq(said))
  end

  def silenced
    order = "lib/app/domain/order.rb"
    quiet = "Page.new # hashira:disable layer_violation -- old"
    layered(%w[web jobs domain], { order => files[order].sub("Page.new", quiet) }).map(&:digest)
  end

  it "is silenced on the line that makes the reference, and ratcheted by its refs" do
    found = layered(%w[web jobs domain]).map { [it.anchors, it.magnitude] }
    expect([found, silenced]).to(
      eq([[[%w[domain/order.rb:4 domain/order.rb:5], 2], [%w[domain/order.rb:6], 1]], ["domain -> jobs"]])
    )
  end
end
