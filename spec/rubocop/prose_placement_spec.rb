# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../.rubocop/cop/hashira/prose_placement"

RSpec.describe(RuboCop::Cop::Hashira::ProsePlacement, :config) do
  include RuboCop::RSpec::ExpectOffense

  it "flags sentence-length string literals" do
    expect_offense(<<~RUBY)
      text = "this package can reach itself and any change may ripple"
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Prose belongs to the presentation layer (report/, ci/) — pass data and phrase it there.
    RUBY
  end
  it "flags interpolated strings whose literal parts read as a sentence" do
    expect_offense(<<~'RUBY')
      text = "#{from} depends on the far less stable package #{to}"
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Prose belongs to the presentation layer (report/, ci/) — pass data and phrase it there.
    RUBY
  end
  it "allows short labels, formatting glue, and word lists" do
    expect_no_offenses(<<~'RUBY')
      arrow = "#{from} -> #{to}"
      stamp = "line#{"s" if lines.size > 1} #{lines.join(", ")}"
      path = "lib/hashira/coupling"
    RUBY
  end
  it "allows prose inside raise" do
    expect_no_offenses(<<~'RUBY')
      raise(Error, "unknown kind #{name} — use one of the listed kinds")
    RUBY
  end
  it "allows shell command strings" do
    expect_no_offenses(<<~RUBY)
      LOG = "git log --name-only --format= 2>/dev/null"
    RUBY
  end
end
