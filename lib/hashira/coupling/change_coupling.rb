# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::ChangeCoupling < Hashira::Coupling::Rule
  KIND = "change_coupling"

  COMMITS = 5

  DEGREE = 50

  FILES = 30

  FLOOR = 8

  SWEEP = 4

  JOINT = " <-> "

  class Bond
    ADVICE = {
      true => "and one refers to the other — every change crosses the package boundary. " \
        "Narrow what one asks of the other, or move them into one package.",
      false => "though neither refers to the other — the coupling is hidden. " \
        "Name what they share in one place both can depend on."
    }.freeze

    def initialize(sides, shared, degree, explicit)
      @sides = sides
      @shared = shared
      @degree = degree
      @explicit = explicit
    end

    def to_h
      files, packages = @sides.transpose
      { files:, packages:, shared: @shared, degree: @degree, explicit: @explicit }
    end

    def phrase(_package)
      first, second = @sides.map { |file, package| "#{file} (#{package})" }
      "#{first} and #{second} changed together in #{@shared} commits, #{@degree}% of their changes, " \
        "#{ADVICE.fetch(@explicit)}"
    end
  end

  class Pair
    def initialize(files, shared, revisions)
      @files = files
      @shared = shared
      @revisions = revisions
    end

    def <=>(other) = rank <=> other.rank

    def joint?(floor) = degree >= floor && yield(@files)

    def finding(kind)
      sides, explicit, anchors = yield(@files)
      shown = sides.map(&:first)
      evidence = shown.zip(@revisions).map { |file, count| "#{file}: #{count} commits" }
      name = Hashira::Analysis::Finding::Name.new(sides.fetch(0).last, [shown.join(JOINT)])
      bond = Bond.new(sides, @shared, degree, explicit)
      Hashira::Analysis::Finding.new(kind, name, bond, Hashira::Analysis::Finding::Proof.new(evidence, anchors))
    end

    protected

    def rank = [-degree, -@shared, @files.join(JOINT)]

    private

    def degree = (200.0 * @shared / @revisions.sum).round
  end

  def list
    return [] unless @plan.traced(&:deep?)
    pairs.sort.map { |pair| pair.finding(KIND) { |files| described(files) } }
  end

  private

  def pairs
    frequent = together.select { |_files, shared| shared >= limit("commits", COMMITS) }
    frequent.map { |files, shared| Pair.new(files, shared, files.map { revisions[it] }) }
      .select { |pair| pair.joint?(limit("degree", DEGREE)) { |files| apart?(files) && !registration?(files) } }
  end

  def revisions = @_revisions ||= changesets.flatten.tally

  def registration?(files) = registered?(files) && !explicit?(files.map { sources.fetch(it) })

  def registered?(files)
    manifests =
      @_manifests ||= Hash.new { |found, file| found[file] = Hashira::Coupling::Manifest.new(file, graph.trees.fetch(sources.fetch(file))) }
    [files, files.reverse].any? { |from, to| manifests[from].names?(to) }
  end

  def limit(name, default) = @rules.limit(KIND, name, default)

  def changesets = @_changesets ||= @plan.traced(&:changesets).map { present(it) }.select { fits?(it) }

  def present(changeset) = changeset.select { sources.key?(it) }

  def fits?(changeset) = changeset.size.between?(1, widest)

  def widest = @_widest ||= [FLOOR, sources.size / SWEEP].max.clamp(..limit("files", FILES))

  def sources = @_sources ||= graph.trees.keys.to_h { [paths.relative(it).b, it] }

  def together
    changesets.each_with_object(Hash.new(0)) do |changeset, counts|
      changeset.sort.combination(2) { counts[it] += 1 }
    end
  end

  def apart?(files)
    files.map { package(it) }.uniq.size == 2
  end

  def package(file) = (@_packages ||= {})[file] ||= graph.home(sources.fetch(file))

  def described(files)
    [files.map { [shown(it), package(it)] }, explicit?(files.map { sources.fetch(it) }), anchors(files)]
  end

  def shown(file) = file.dup.force_encoding(Encoding::UTF_8)

  def explicit?(files) = [files, files.reverse].any? { links.include?(it) }

  def links
    @_links ||=
      graph.sightings.each_with_object(Set.new) do |sighting, found|
        graph.files(sighting.path).each { found << [sighting.file, it] }
      end
  end

  def anchors(files)
    files.map do |file|
      first = graph.trees.fetch(sources.fetch(file)).statements.body.first
      "#{shown(file)}:#{first ? first.location.start_line : 1}"
    end
  end
end
