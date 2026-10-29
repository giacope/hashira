# frozen_string_literal: true

class Hashira::Coupling::RollCall
  MIN_WORDS = 3

  MIN_FILES = 3

  MIN_PACKAGES = 2

  SHARE = 0.6

  GENERIC = %w[
    id created_at updated_at type name properties required items description title enum format default minimum
    maximum pattern additional_properties
  ].to_set.freeze

  class Roll
    def initialize(words, files, packages, sites)
      @words = words
      @files = files
      @packages = packages
      @sites = sites
    end

    def to_h = { words: @words, files: @files, packages: @packages }

    def phrase(_package)
      "the words #{@words.join(", ")} are listed together in #{@files.join(", ")} — " \
        "#{@packages.size} packages keep one roll-call in sync by hand. Make the list data with a single owner."
    end

    def within?(words) = words.superset?(@words.to_set)

    def swallows?(small) = @words != small.words && (small.words - @words).empty?

    def finding(kind)
      name = Hashira::Analysis::Finding::Name.new(@packages.fetch(0), [@words.join(",")])
      Hashira::Analysis::Finding.new(kind, name, self, Hashira::Analysis::Finding::Proof.new(@sites))
    end

    def <=>(other) = @words <=> other.words

    protected

    attr_reader :words
  end

  def initialize(lists, homes)
    @raw = lists
    @homes = homes
  end

  def rolls
    found = candidates.filter_map { entry(it) }
    found.reject { |roll| found.any? { it.swallows?(roll) } }.sort
  end

  private

  def lists = @_lists ||= @raw.transform_values { |literals| literals.map { it.with(words: it.words - GENERIC) } }

  def files = @_files ||= lists.keys.sort

  def candidates
    pairs = files.combination(2).flat_map { |one, two| lists[one].product(lists[two]) }
    pairs.flat_map { |mine, theirs| shared(mine, theirs) }.uniq
  end

  def shared(mine, theirs)
    words = mine.words & theirs.words
    words.size >= MIN_WORDS && most?(words, mine) && most?(words, theirs) ? [words] : []
  end

  def most?(words, literal) = words.size >= SHARE * literal.words.size

  def holding(file, words) = lists[file].select { it.words >= words && most?(words, it) }

  def entry(words)
    holders = files.select { holding(it, words).any? }
    spread = holders.map { @homes[it] }.uniq.sort
    return unless holders.size >= MIN_FILES && spread.size >= MIN_PACKAGES
    sites = holders.map { "#{it}:#{holding(it, words).fetch(0).line}" }
    Roll.new(words.sort, holders, spread, sites)
  end
end
