# frozen_string_literal: true

RSpec.describe(Hashira::Boundaries) do
  def declaration(**changes)
    {
      "root" => "Prism", "role" => "interpreted_model",
      "entrypoint" => "lib/app/trees.rb", "reason" => "the AST is the input model"
    }.merge(changes.transform_keys(&:to_s))
  end

  def interpreted(records, files = sources)
    within(files) do
      project = Hashira::Project.new(["lib/app"])
      trees = Hashira::Trees.new(project).all
      yield(described_class.new(records, trees))
    end
  end

  def sources
    {
      "lib/app/trees.rb" => "class Trees; def parse = Prism.parse('1').value; end\n",
      "lib/app/check.rb" => "class Check; def call(node) = node.is_a?(Prism::CallNode); end\n"
    }
  end

  it "recognizes a foreign model whose root API has one declared entrypoint" do
    interpreted([declaration]) { |boundaries| expect(boundaries.interpreted).to(eq(["Prism"])) }
  end

  it "has no interpreted models without declarations" do
    interpreted([]) { |boundaries| expect(boundaries.interpreted).to(be_empty) }
  end

  %i[root entrypoint reason].product([nil, ""]).each do |field, value|
    it "rejects a declaration with a missing #{field}" do
      interpreted([declaration(field => value)]) do |boundaries|
        expect { boundaries.interpreted }.to(raise_error(Hashira::Error, /boundary.*#{field}/))
      end
    end
  end

  it "names the declaration's root when another field is missing" do
    interpreted([declaration(entrypoint: nil)]) do |boundaries|
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, "boundary Prism entrypoint is missing"))
    end
  end

  it "calls the declaration unknown when its root is missing" do
    interpreted([declaration(root: nil)]) do |boundaries|
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, "boundary (unknown) root is missing"))
    end
  end

  it "rejects a declaration which is not an object" do
    interpreted(["Prism"]) do |boundaries|
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, /not an object/))
    end
  end

  it "rejects declarations with an unknown role" do
    interpreted([declaration(role: "adapter")]) do |boundaries|
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, /unknown role "adapter"/))
    end
  end

  it "rejects a declaration when its root is never called" do
    quiet = sources.merge("lib/app/trees.rb" => "class Trees; def parse = 1; end\n")
    interpreted([declaration], quiet) do |boundaries|
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, /has no root calls/))
    end
  end

  it "rejects root API calls which bypass the declared entrypoint" do
    bypassed = sources.merge("lib/app/other.rb" => "class Other; def parse = Prism.parse('2').value; end\n")
    interpreted([declaration], bypassed) do |boundaries|
      failure = %r{bypasses lib/app/trees\.rb: lib/app/other\.rb}
      expect { boundaries.interpreted }.to(raise_error(Hashira::Error, failure))
    end
  end
end
