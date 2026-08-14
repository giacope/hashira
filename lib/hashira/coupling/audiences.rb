# frozen_string_literal: true

class Hashira::Coupling::Audiences
  MIN = 2

  Part = Data.define(:users, :constants, :shared)

  def initialize(usage)
    @usage = usage
  end

  def split? = parts.size >= 2

  def parts = @_parts ||= [common, *slices].compact.select { it.constants.size >= MIN }

  private

  def clients = @_clients ||= @usage.keys.sort

  def shared = @_shared ||= tally.select { |_constant, users| users.size * 2 > clients.size }.keys.to_set

  def tally
    clients.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |client, seen|
      @usage[client].each { seen[it] << client }
    end
  end

  def common
    return if shared.empty?
    Part.new(users: clients.select { @usage[it].intersect?(shared) }, constants: shared.sort, shared: true)
  end

  def slices
    groups.sort_by(&:first).map { |members| Part.new(users: members, constants: pooled(members).sort, shared: false) }
  end

  def pooled(members) = members.reduce(Set.new) { |pool, client| pool | residue(client) }

  def residue(client) = @usage[client] - shared

  def groups
    clients.reduce([]) do |formed, client|
      linked, apart = formed.partition { |members| joined?(members, client) }
      apart + [linked.flatten + [client]]
    end
  end

  def joined?(members, client) = members.any? { residue(it).intersect?(residue(client)) }
end
