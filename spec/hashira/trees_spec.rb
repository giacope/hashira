# frozen_string_literal: true

RSpec.describe(Hashira::Trees) do
  it "lists the files Prism could not parse, even when asked before any tree" do
    within("lib/app/good.rb" => "class Good; end\n", "lib/app/bad.rb" => "class Bad\n") do
      expect(described_class.new(Hashira::Project.new(["lib/app"])).unparsed).to(eq(["lib/app/bad.rb"]))
    end
  end

  it "reports an unreadable path with the system's reason" do
    within("lib/app/good.rb" => "class Good; end\n") do
      Dir.mkdir("lib/app/odd.rb")
      failure = "cannot read lib/app/odd.rb (Is a directory - lib/app/odd.rb)"
      expect { described_class.new(Hashira::Project.new(["lib/app"])).all }.to(raise_error(Hashira::Error, failure))
    end
  end
end
