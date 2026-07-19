# frozen_string_literal: true

require_relative "lib/hashira/version"

Gem::Specification.new do |spec|
  spec.name = "hashira"
  spec.version = Hashira::VERSION
  spec.authors = ["Giacomo GK"]
  spec.email = ["giaco@hey.com"]

  spec.summary = "Package coupling metrics for Ruby, via Prism"
  spec.description = "Measures package coupling in a Ruby codebase (Ca/Ce/instability, SDP " \
                     "violations, cycles) from the AST, with findings backed by file-level " \
                     "evidence and an edge-set ratchet for CI."
  spec.homepage = "https://github.com/giacope/hashira"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "CHANGELOG.md", "LICENSE*"]
  spec.bindir = "exe"
  spec.executables = ["hashira"]
  spec.require_paths = ["lib"]
end
