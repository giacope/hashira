# frozen_string_literal: true

RSpec.describe(Hashira::Snapshot) do
  def taken(&)
    within("lib/app/thing.rb" => "class Thing; def a = 1; end\n") do
      yield(described_class.new(Hashira::Project.new(["lib/app"])))
    end
  end

  it "lists the files it will read" do
    taken { |snapshot| expect(snapshot.paths).to(eq(["lib/app/thing.rb"])) }
  end

  it "counts them" do
    taken { |snapshot| expect(snapshot.size).to(eq(1)) }
  end

  it "reads each file once, so a rewrite mid-run cannot change the answer" do
    taken do |snapshot|
      before = snapshot.sources.fetch("lib/app/thing.rb")
      File.write("lib/app/thing.rb", "class Thing; def a = 2; end\n")
      expect(snapshot.sources.fetch("lib/app/thing.rb")).to(eq(before))
    end
  end

  it "keeps the file list steady when a file appears after the run started" do
    taken do |snapshot|
      snapshot.paths
      File.write("lib/app/late.rb", "class Late; def a = 1; end\n")
      expect(snapshot.paths).to(eq(["lib/app/thing.rb"]))
    end
  end

  it "names the file it could not read" do
    taken do |snapshot|
      allow(File).to(receive(:read).and_raise(Errno::EACCES, "lib/app/thing.rb"))
      expect { snapshot.sources }.to(raise_error(Hashira::Error, %r{cannot read lib/app/thing\.rb}))
    end
  end

  it "is what the run reports its file count from" do
    within("lib/app/thing.rb" => "class Thing; def a = 1; end\n") do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["lib/app"])).tap(&:findings)
      File.write("lib/app/late.rb", "class Late; def a = 1; end\n")
      expect(pipeline.snapshot.size).to(eq(1))
    end
  end
end
