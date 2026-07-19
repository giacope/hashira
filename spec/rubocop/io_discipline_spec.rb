# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../.rubocop/cop/hashira/io_discipline"

RSpec.describe RuboCop::Cop::Hashira::IoDiscipline, :config do
  include RuboCop::RSpec::ExpectOffense

  it "flags bare output calls" do
    expect_offense(<<~RUBY)
      puts "report"
      ^^^^^^^^^^^^^ Write through the injected `@io`, not bare `puts`.
      warn "oops"
      ^^^^^^^^^^^ Write through the injected `@io`, not bare `warn`.
    RUBY
  end

  it "allows writing through a receiver" do
    expect_no_offenses(<<~RUBY)
      @io.puts "report"
      $stderr.puts "oops"
    RUBY
  end
end
