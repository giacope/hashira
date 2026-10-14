# frozen_string_literal: true

class Evaluation::Sniff
  def initialize(name, expect, findings)
    @name = name
    @expect = expect
    @findings = findings
  end

  def checks = [*listed(:present), *listed(:absent), *evidence, *messages]

  private

  def check(label, expected, actual)
    Evaluation::Check.of(Evaluation::Smells::SUITE, "#{@name}: #{label}", expected, actual)
  end

  def listed(state)
    @expect.fetch(state.to_s, []).map { check(named(it), state, Evaluation::SEEN.fetch(matching(it).any?)) }
  end

  def named(want) = [want["kind"], want["package"]].compact.join(" ")

  def matching(want) = @findings.select { it["kind"] == want["kind"] && [nil, it["package"]].include?(want["package"]) }

  def evidence
    @expect.fetch("evidence", []).map do |kind|
      check("every #{kind} finding names its evidence", [], @findings.select { bare?(it, kind) }.map { it["package"] })
    end
  end

  def bare?(finding, kind) = finding["kind"] == kind && finding["evidence"].empty?

  def messages
    @expect.fetch("messages", []).map do |want|
      said = matching(want).map { it["message"] }.join(" | ")
      check("#{named(want)} says #{want["includes"].inspect}", :said, said.include?(want["includes"]) ? :said : said)
    end
  end
end
