# frozen_string_literal: true

require "json"

class Hashira::CI::Accepted
  Screened = Data.define(:all, :accepted)

  class Entry
    def self.build(hash) = new(hash["kind"], hash["package"], hash["digest"], hash["reason"])

    def initialize(kind, package, digest, reason)
      @kind = kind
      @package = package
      @digest = digest
      @reason = reason
    end

    def matches?(finding) = @kind == finding.kind && (@digest || @package) == finding.identity

    def label = @reason || "accepted (no reason recorded)"

    def to_h = { kind: @kind, package: @package, digest: @digest, reason: @reason }.compact
  end

  def self.build(path) = new(Hashira::CI::Baseline.new(path).accepted)

  def initialize(list)
    @list = list
  end

  def entries = records.map(&:to_h)

  def screen(findings)
    accepted = findings.flat_map { |finding| reasons(finding).map { [finding, it] } }
    Screened.new(all: findings - accepted.map(&:first), accepted:)
  end

  private

  def records = @_records ||= @list.map { Entry.build(it) }

  def reasons(finding) = records.select { it.matches?(finding) }.first(1).map(&:label)
end
