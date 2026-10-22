# frozen_string_literal: true

RSpec.describe(Hashira::Trees, :aggregate_failures) do
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

  def read(source)
    within("lib/app/file.rb" => source) do
      trees = described_class.new(Hashira::Project.new(["lib/app"]))
      word = trees.all.fetch("lib/app/file.rb").statements.body.first.value.unescaped
      return [trees.lines("lib/app/file.rb"), word, trees.unparsed]
    end
  end

  it "decodes a file its magic comment declares in another encoding" do
    expect(read("# encoding: Shift_JIS\n# \x82\xA0\nWORD = \"\x82\xA2\"\n".b)).to(
      eq([["# encoding: Shift_JIS\n", "# あ\n", "WORD = \"い\"\n"], "い", []])
    )
  end

  it "replaces the bytes a binary file holds above ASCII" do
    expect(read("# encoding: binary\nRAW = \"\xFF\" # \xFE\n".b)).to(
      eq([["# encoding: binary\n", "RAW = \"\uFFFD\" # \uFFFD\n"], "\uFFFD", []])
    )
  end

  it "replaces the stray bytes of a UTF-8 file, in a comment or in code" do
    expect(read("# \xFF\nBAD = \"\xFE\"\n".b)).to(eq([["# \uFFFD\n", "BAD = \"\uFFFD\"\n"], "\uFFFD", []]))
  end
end
