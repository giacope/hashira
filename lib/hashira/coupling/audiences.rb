# frozen_string_literal: true

class Hashira::Coupling::Audiences
  MIN = 2

  FLOOR = 3

  class Part
    def initialize(users:, constants:, shared:)
      @users = users
      @constants = constants
      @shared = shared
    end

    def to_h = { users: @users, constants: @constants, shared: @shared }

    def to_s = "#{@users.join(", ")} #{verb} #{@constants.join(", ")}"

    def shared? = @shared

    def heavy?(sizes) = @constants.size >= MIN && @users.sum { sizes.fetch(it, FLOOR) } >= FLOOR

    def sightings(package, graph)
      @users.flat_map { |client| graph.evidence(client, package).to_a.select { mentions?(it) } }
    end

    private

    def verb
      return "share" if @shared
      @users.one? ? "alone uses" : "use"
    end

    def mentions?(line)
      reference = "::#{line.rpartition(": ").last}::"
      @constants.any? { reference.include?("::#{it}::") }
    end
  end

  def initialize(usage, sizes = {})
    @usage = usage
    @sizes = sizes
  end

  def split? = parts.size >= 2

  def parts = @_parts ||= [common, *slices].select { it.heavy?(@sizes) }

  private

  def clients = @_clients ||= @usage.keys.sort

  def shared = @_shared ||= tally.select { |_constant, users| users.size * 2 > clients.size }.keys.to_set

  def tally
    clients.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |client, seen|
      @usage[client].each { seen[it] << client }
    end
  end

  def common
    Part.new(users: clients.select { @usage[it].intersect?(shared) }, constants: shared.sort, shared: true)
  end

  def slices
    groups.sort_by(&:first).map do |members|
      pooled = members.reduce(Set.new) { |pool, client| pool | residue(client) }
      Part.new(users: members, constants: pooled.sort, shared: false)
    end
  end

  def residue(client) = @usage[client] - shared

  def groups
    clients.reduce([]) do |formed, client|
      linked, apart = formed.partition { |members| joined?(members, client) }
      apart + [linked.flatten + [client]]
    end
  end

  def joined?(members, client) = members.any? { residue(it).intersect?(residue(client)) }
end
