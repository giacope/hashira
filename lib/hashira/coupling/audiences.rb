# frozen_string_literal: true

class Hashira::Coupling::Audiences
  MIN = 2

  FLOOR = 3

  Part = Data.define(:users, :constants, :shared)

  def initialize(usage, sizes = {})
    @usage = usage
    @sizes = sizes
  end

  def split? = parts.size >= 2

  def parts
    @_parts ||=
      [common, *slices].select do |part|
        part.constants.size >= MIN && part.users.sum { @sizes.fetch(it, FLOOR) } >= FLOOR
      end
  end

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
