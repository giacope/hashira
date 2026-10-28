# frozen_string_literal: true

class Evaluation::Home
  ROOT = File.expand_path("../..", __dir__)

  private_constant :ROOT

  def initialize(root = ROOT)
    @root = root
  end

  def join(*parts) = File.join(@root, *parts)

  def cases(*parts) = join("cases", *parts)
end
