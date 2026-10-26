# frozen_string_literal: true

RSpec.describe(Hashira::Smells::ConcreteInheritance, :aggregate_failures) do
  def concrete(source, extra = "")
    sniffed({ "lib/app/report.rb" => source, "lib/app/use.rb" => extra }, "concrete_inheritance")
  end

  def reports(base = "", child = "Daily < Report") = <<~RUBY
    module App
      class Report#{base}
        def rows = [1]
      end

      class #{child}
        def rows = [2]
      end
    end
  RUBY

  def built(call = "Report.new") = "module App\n  class Runner\n    def run = #{call}.rows\n  end\nend\n"

  def reopened(reopening)
    report = reports(" < ActiveRecord::Base").sub("def rows = [2]", "def extra = [2]")
    files = { "lib/app/ext.rb" => reopening, "lib/app/report.rb" => report, "lib/app/use.rb" => built }
    sniffed(files, "concrete_inheritance")
  end

  it "leaves a hierarchy alone whose root extends a library class the project only reopens" do
    reopenings = [
      "class ActiveRecord::Base\n  def tagged = 1\nend\n",
      "ActiveRecord::Base.class_eval { def tagged = 1 }\n"
    ]
    expect(reopenings.map { reopened(it) }).to(all(be_empty))
  end

  it "sites the parent at its definition, not at a block that reopens it in an earlier file" do
    files = {
      "lib/app/a_ext.rb" => "App::Report.class_eval do\n  def extra = 1\nend\n",
      "lib/app/report.rb" => reports, "lib/app/use.rb" => built
    }
    expect(sniffed(files, "concrete_inheritance").map { it.detail.home }).to(eq(["report.rb:2"]))
  end

  it "flags a subclass of an owned class that the project also builds on its own, naming where" do
    finding = concrete(reports, built).first
    expect([finding.package, finding.detail.to_h, finding.evidence]).to(
      eq(
        [
          "App::Daily", { site: "report.rb:6", parent: "App::Report", home: "report.rb:2", mode: :built },
          ["App::Report.new (use.rb:3)"]
        ]
      )
    )
  end

  def labelled(parent) = "module App\n  class Label < #{parent}\n    def tag = self\n  end\nend\n"

  it "flags a subclass of a concrete core collection or value class" do
    reopened = "class String\n  def shout = upcase\nend\n"
    found = %w[String ::Array Hash Set].map { concrete(reopened + labelled(it)).map { [it.package, it.detail.parent] } }
    expect(found).to(eq(%w[String Array Hash Set].map { [["App::Label", it]] }))
  end

  it "says a core class's subclass to hold one instead" do
    said = "App::Label extends Hash, a concrete core class (report.rb:2). Keep one in a field and give the class " \
      "methods of its own: what it inherits (map, select, merge) answers a plain Hash, not this class."
    expect(message(concrete(labelled("Hash")).first)).to(eq(said))
  end

  it "leaves a subclass of a core class that is not a collection or a value alone" do
    parents = %w[StandardError Struct SimpleDelegator Object].map { "module App\n  class Label < #{it}\n  end\nend\n" }
    expect(parents.map { concrete(it) }).to(all(be_empty))
  end

  it "says what the parent is and what to do" do
    said = "App::Daily inherits from App::Report, a concrete class the project also builds (report.rb:6). " \
      "Extract what they share into an abstract base both extend, or compose instead."
    expect(message(concrete(reports, built).first)).to(eq(said))
  end

  it "leaves a subclass alone when nothing builds its parent, or only builds the subclass" do
    expect([concrete(reports), concrete(reports, built("Daily.new"))]).to(all(be_empty))
  end

  it "resolves the built constant lexically, from the caller's namespace outward, and through a full path" do
    paths = ["App::Report.new", "::App::Report.new"].map { concrete(reports, built(it)).size }
    other = concrete(reports, "module Else\n  class Report\n  end\n\n  def self.go = Report.new\nend\n")
    expect(paths + [other.size]).to(eq([1, 1, 0]))
  end

  it "names nothing built by a new on a computed receiver" do
    expect(concrete(reports.sub("def rows = [1]", "def rows = [1]\n    def twin = self.class.new"))).to(be_empty)
  end

  it "counts a bare new in the parent's class methods as building it only when the parent is sent that method" do
    factories = ["def self.build = new", "class << self\n      def build = new\n    end", "def self.build = Report.new"]
    sources = factories.map { reports.sub("def rows = [1]", "#{it}\n    def rows = [1]") }
    callers = %w[Report.build Daily.build].map { built(it) }
    expect(sources.product(callers).map { |source, caller| concrete(source, caller).size }).to(eq([1, 0, 1, 0, 1, 1]))
  end

  it "leaves a parent alone that announces itself abstract by name, a hook left unimplemented, or a marker" do
    hooks = ["def rows = raise(NotImplementedError)", "def rows\n      raise NotImplementedError, 'subclass'\n    end"]
    marked = ["self.abstract_class = true", "abstract!"].map { "#{it}\n    def rows = [1]" }
    parents = (hooks + marked).map { reports.sub("def rows = [1]", it) }
    named = %w[Base AbstractReport ReportBase BaseReport].map { name(it) }
    expect((parents.map { concrete(it, built) } + named).map(&:size)).to(eq([0] * 8))
  end

  it "still flags a parent whose methods raise something other than the unimplemented error" do
    expect(concrete(reports.sub("def rows = [1]", "def rows = raise(ArgumentError)"), built).size).to(eq(1))
  end

  it "leaves a hierarchy alone whose owned root extends a framework class, when subclasses only add to it" do
    adding = reports(" < ActiveRecord::Base").sub("def rows = [2]", "def extra = [2]")
    framed = [" < StandardError", " < ActiveRecord::Base", " < Struct.new(:id)"].map { reports(it).sub("def rows = [2]", "def extra = [2]") }
    root = adding.sub(" < ActiveRecord::Base", " < Root").sub(
      "module App\n",
      "module App\n  class Root < StandardError\n  end\n\n"
    )
    expect((framed + [root]).map { concrete(it, built) }).to(all(be_empty))
  end

  it "flags a subclass under a framework root that overrides a working method of its concrete parent (STI)" do
    found = [" < ActiveRecord::Base", " < StandardError"].map { concrete(reports(it)).map { [it.package, it.evidence] } }
    expect(found).to(eq([[["App::Daily", ["App::Daily#rows (report.rb:7)"]]]] * 2))
    said = "App::Daily overrides working methods of App::Report, a concrete class (report.rb:6). " \
      "Extract what they share into an abstract base both extend, or compose instead."
    expect(message(concrete(reports(" < ActiveRecord::Base")).first)).to(eq(said))
  end

  it "takes a subclass's own constructor for construction, not an override, and a Base-named parent for abstract" do
    constructor = reports(" < StandardError").sub("def rows = [2]", "def initialize(rows) = super(rows.to_s)")
    based = reports(" < ActiveRecord::Base").gsub("Report", "BaseReport")
    expect([constructor, based].map { concrete(it) }).to(all(be_empty))
  end

  it "takes a core-named parent the namespace defines for that class, not the core one" do
    owned = "module App\n  class Hash < ::Hash\n  end\n\n  class Mash < Hash\n  end\nend\n"
    expect(concrete(owned).map(&:package)).to(eq(["App::Hash"]))
  end

  it "leaves an override alone under a framework root when the parent is abstract or the method a hook or a refusal" do
    abstract = reports(" < ActiveRecord::Base").sub("def rows = [1]", "self.abstract_class = true\n    def rows = [1]")
    hook = reports(" < ActiveRecord::Base").sub("def rows = [1]", "def rows = raise(NotImplementedError)")
    empty = reports(" < ActiveRecord::Base").sub("def rows = [1]", "def rows = nil")
    refused = reports(" < ActiveRecord::Base").sub("def rows = [2]", "def rows = raise(ArgumentError)")
    expect([abstract, hook, empty, refused].map { concrete(it) }).to(all(be_empty))
  end

  it "flags a deeper subclass of a built class whose owned ancestors extend nothing foreign" do
    root = reports(" < Root").sub("module App\n", "module App\n  class Root\n  end\n\n")
    expect(concrete(root, built).map(&:package)).to(eq(["App::Daily"]))
  end

  it "lists at most three of the places that build the parent" do
    many = "module App\n  class Runner\n#{(1..4).map { "    def r#{it} = Report.new\n" }.join}  end\nend\n"
    expect(concrete(reports, many).first.evidence.size).to(eq(3))
  end

  it "survives classes that name each other as parents" do
    loop = "module App\n  class A < B\n    def go = 1\n  end\n\n  class B < A\n    def go = 2\n  end\nend\n"
    expect(concrete(loop, "module App\n  class C\n    def go = [A.new, B.new]\n  end\nend\n").size).to(eq(2))
  end

  def name(parent)
    concrete(reports.gsub("Report", parent), built("#{parent}.new"))
  end
end
