# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Outside) do
  def files
    {
      "lib/app/a.rb" => "in_code\n", "lib/app/view.erb" => "in_view\n", "spec/a_spec.rb" => "in_spec?\n",
      "Rakefile" => "in_rakefile\n", "bin/tool" => "in_script\n", "notes.md" => "in_notes\n",
      "plugin/config.json" => "{\"on_active\": [\"in_json\"]}\n", "templates/model.rb.tt" => "in_template\n",
      "vendor/gem.rb" => "in_vendor\n", "big.rb" => "in_big #{"x" * 1_000_001}\n",
      "edge.rb" => "in_edge #{"x" * 999_991}\n"
    }
  end

  def words = described_class.new(Hashira::Project.new(["lib/app"])).words.grep(/\Ain_/).sort

  it "reads the words of the project's other files, past the analyzed code and what is vendored or huge" do
    within(files) { expect(words).to(eq(%w[in_edge in_json in_rakefile in_script in_spec? in_template in_view])) }
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
    within(files) { expect(without_git).to(eq(%w[in_edge in_json in_rakefile in_script in_spec? in_template in_view])) }
  end
end
