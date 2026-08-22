# frozen_string_literal: true

RSpec.describe(Hashira::Constraints::Reading) do
  def read(yaml, &)
    within(yaml ? { ".hashira.yml" => yaml, "lib/app/x.rb" => "class X; def a = 1; end\n" } : {}) do
      yield(described_class.new(".hashira.yml"))
    end
  end

  def refused(yaml, &) = read(yaml) { |reading| yield(reading.trouble.to_s) }

  it "reads nothing when the project declares nothing" do
    read(nil) { |reading| expect(reading.declarations.empty?).to(be(true)) }
  end

  it "reads a declared fact and its scope" do
    read(Fixtures::BOTH_FACTS) { |reading| expect(reading.declarations.empty?).to(be(false)) }
  end

  it "keeps a declaration recorded twice only once" do
    yaml = "constraints:\n  - fact: no_method_missing\n    scope: lib/\n  - fact: no_method_missing\n    scope: lib\n"
    read(yaml) { |reading| expect(reading.declarations.identity).to(eq(["no_method_missing@1.0.0:lib"])) }
  end

  it "stamps each declaration with the fact, hashira's edition of it, and the normalized scope" do
    read(Fixtures::BOTH_FACTS) do |reading|
      expect(reading.declarations.identity).to(eq(["no_define_method@1.0.0:lib", "no_method_missing@1.0.0:lib"]))
    end
  end

  it "refuses a fact hashira does not own" do
    refused("constraints:\n  - fact: no_magic\n    scope: lib/\n") do |trouble|
      expect(trouble).to(include('unknown fact "no_magic"', "no_define_method, no_method_missing"))
    end
  end

  it "refuses a scope that is not a directory" do
    refused("constraints:\n  - fact: no_method_missing\n    scope: nowhere/\n") do |trouble|
      expect(trouble).to(include('scope "nowhere/" is not a directory'))
    end
  end

  it "refuses a scope that climbs out of the project" do
    refused("constraints:\n  - fact: no_method_missing\n    scope: ../elsewhere\n") do |trouble|
      expect(trouble).to(include("must name a path inside the project"))
    end
  end

  it "refuses an absolute scope" do
    refused("constraints:\n  - fact: no_method_missing\n    scope: /etc\n") do |trouble|
      expect(trouble).to(include("must name a path inside the project"))
    end
  end

  it "refuses an empty scope" do
    refused("constraints:\n  - fact: no_method_missing\n    scope: ''\n") do |trouble|
      expect(trouble).to(include("must name a path inside the project"))
    end
  end

  it "refuses constraints that are not a list" do
    refused("constraints: no_method_missing\n") do |trouble|
      expect(trouble).to(include("must be a list of entries, not string"))
    end
  end

  it "refuses an entry that is not a mapping" do
    refused("constraints:\n  - no_method_missing\n") do |trouble|
      expect(trouble).to(include("must be a mapping with a fact: and a scope:"))
    end
  end

  it "refuses a document whose top level is a list" do
    refused("- one\n- two\n") { |trouble| expect(trouble).to(include("must be a mapping of settings, not array")) }
  end

  it "refuses YAML it cannot parse" do
    refused("constraints: [\n") { |trouble| expect(trouble).to(include("hashira reads it as YAML")) }
  end

  it "reads an empty file as no settings at all" do
    read("") { |reading| expect(reading.declarations.empty?).to(be(true)) }
  end

  it "names the file it is complaining about" do
    refused("constraints: no_method_missing\n") { |trouble| expect(trouble).to(start_with(".hashira.yml:")) }
  end
end
