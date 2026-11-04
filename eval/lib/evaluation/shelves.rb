# frozen_string_literal: true

class Evaluation::Shelves
  def initialize(home = Evaluation::Home.new)
    @home = home
  end

  def labels(seed) = seed.empty? ? results("labels") : results("labels", "holdout", seed)

  def raters = [results("blind"), results("blind2")]

  def drawn = Dir.glob(results("{holdout,human}", "*"))

  def pending(seed) = seed.empty? ? @home.join("tmp", "pending") : @home.join("tmp", "holdout", seed)

  private

  def results(*parts) = @home.join("results", *parts)
end
