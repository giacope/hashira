# frozen_string_literal: true

class Hashira::Coupling::Hosting
  def initialize(heritage, handover, entered, registry)
    @heritage = heritage
    @handover = handover
    @entered = entered
    @registry = registry
  end

  def held?(path, hosts)
    @registry.registered?(path) || hosted?(path) || hosts.any? { hosted?(it) } || @registry.loaded?(path)
  end

  def hosted?(path) = hosted[path]

  def backed?(path) = [path, *@heritage.mixers(path)].any? { @heritage.outside?(it) }

  def patched?(path) = [path, *hosts(path)].any? { @handover.foreign?(it) || @heritage.patched?(it) }

  private

  def hosted = @_hosted ||= Hash.new { |found, path| found.store(path, false) || found[path] = settle(path) }

  def settle(path) = @heritage.lineage(path).any? { @heritage.outside?(it) } || hosting?(path)

  def hosting?(path)
    @handover.told?(path) || hosts(path).any? { @handover.foreign?(it) || hosted?(it) || @entered.include?(it) }
  end

  def hosts(path) = @heritage.mixers(path) + @handover.hosts(path)
end
