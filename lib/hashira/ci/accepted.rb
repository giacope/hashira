# frozen_string_literal: true

require "json"

class Hashira::CI::Accepted
  class Screened
    def initialize(kept, waived)
      @kept = kept
      @waived = waived
    end

    def to_a = @kept

    def to_h = @waived.to_h
  end

  class Entry
    SIGNATURE = ->(signature, _magnitude, _traces) { signature }

    def self.build(hash) = new(hash["kind"], hash["package"], hash["digest"], hash["reason"])

    def initialize(kind, package, digest, reason)
      @kind = kind
      @package = package
      @digest = digest
      @reason = reason
    end

    def matches?(finding) = finding.of?([@kind]) && finding.scored(SIGNATURE) == "#{@kind}:#{@digest || @package}"

    def label = @reason || "accepted (no reason recorded)"

    def to_h = { kind: @kind, package: @package, digest: @digest, reason: @reason }.compact
  end

  def self.build(path) = Hashira::CI::Baseline.new(path).accepted

  def initialize(list, boundaries = [])
    @list = list
    @boundaries = boundaries
  end

  def screen(findings)
    accepted = findings.flat_map { |finding| reasons(finding).map { [finding, it] } }
    Screened.new(findings - accepted.map(&:first), accepted)
  end

  def boundaries(declared) = @boundaries + declared

  def to_h = { accepted: records.map(&:to_h), boundaries: @boundaries }.reject { |_name, values| values.empty? }

  private

  def records = @_records ||= @list.map { Entry.build(it) }

  def reasons(finding) = records.select { it.matches?(finding) }.first(1).map(&:label)
end
