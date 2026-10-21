# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Outside) do
  def files
    {
      "lib/app/a.rb" => "in_code\n", "lib/app/view.erb" => "in_view\n", "spec/a_spec.rb" => spec,
      "spec/factories/users.rb" => "in_factory { 1 }\n",
      "Rakefile" => "in_rakefile\n", "bin/tool" => "in_script\n", "notes.md" => "in_notes\n",
      "plugin/config.json" => "{\"on_active\": [\"in_json\"]}\n", "templates/model.rb.tt" => "in_template\n",
      "vendor/gem.rb" => "in_vendor\n", "big.rb" => "in_big #{"x" * 1_000_001}\n",
      "edge.rb" => "in_edge #{"x" * 999_991}\n"
    }
  end

  def spec
    "subject.in_spec?\nin_local = in_call(1)\nexpect(it).to be_in_matcher\n" \
      "[:in_symbol].map(&:in_proc)\nit { InRecord }\nlet(:in_let) { 1 }\nlet!( :in_bang) { 1 }\n" \
      "subject(:in_subject) { 1 }\n"
  end

  def read = %w[in_call in_edge in_factory in_json in_matcher? in_proc in_rakefile in_script in_spec? in_symbol]

  def words = described_class.new(Hashira::Project.new(["lib/app"])).words.grep(/\Ain_/).sort

  it "reads the words of the project's other files, past the analyzed code and what is vendored or huge" do
    within(files) { expect(words).to(eq(read + %w[in_template in_view])) }
  end

  it "lists a repository's files through git, ignored ones aside" do
    within(files.merge(".gitignore" => "spec/\n")) do
      git("init", "-q")
      expect(words).to(eq(%w[in_edge in_json in_rakefile in_script in_template in_vendor in_view]))
    end
  end

  def without_git
    path = ENV.fetch("PATH", nil)
    ENV["PATH"] = ""
    words
  ensure
    ENV["PATH"] = path
  end

  it "walks the folder when git cannot run" do
    within(files) { expect(without_git).to(eq(read + %w[in_template in_view])) }
  end

  it "reads a gem's README and docs, an RSpec predicate matcher as its predicate, and a constant a spec names" do
    docs = { "shop.gemspec" => "", "README.md" => "in_readme\n", "docs/guide/setup.md" => "in_docs\n" }
    found = within(files.merge(docs)) { described_class.new(Hashira::Project.new(["lib/app"])).words }
    expect(found.grep(/\Ain_(?:readme|docs|notes)|\Ahas_|\AInRecord/).sort).to(eq(%w[InRecord in_docs in_readme]))
  end

  it "maps have_x to has_x?" do
    found =
      within("spec/a_spec.rb" => "expect(cart).to have_items\n", "lib/app/a.rb" => "") do
        described_class.new(Hashira::Project.new(["lib/app"])).words
      end
    expect(found).to(include("has_items?"))
  end
end
