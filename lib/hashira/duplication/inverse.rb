# frozen_string_literal: true

class Hashira::Duplication::Inverse
  PAIR = 2
  PREFIXES = %w[un de dis].freeze
  ANTONYMS = %w[
    open/close start/stop show/hide add/remove push/pop enable/disable increment/decrement increase/decrease
    on/off in/out up/down attach/detach encode/decode encrypt/decrypt grant/revoke allow/deny accept/reject
    approve/reject login/logout import/export expand/collapse pause/resume upvote/downvote before/after
    min/max first/last next/previous prev/next include/exclude credit/debit
  ].map { it.split("/") }.freeze

  def initialize(cluster, definitions)
    @cluster = cluster
    @definitions = definitions
  end

  def inverse? = @cluster.size == PAIR && opposed?(*@cluster.sites.map { words(it) })

  private

  def words(site) = name(enclosing(site)).sub(/[!?=]\z/, "").split("_")

  def enclosing(site) = @definitions.select { site.within?([it]) }.max_by(&:line)

  def name(definition) = definition ? definition.roots.first.name.to_s : ""

  def opposed?(left, right)
    differing = left.zip(right).reject { |one, two| one == two }
    left.size == right.size && differing.one? && antonyms?(*differing.first)
  end

  def antonyms?(one, two) = paired?(one, two) || paired?(two, one)

  def paired?(one, two) = ANTONYMS.include?([one, two]) || PREFIXES.any? { two == "#{it}#{one}" }
end
