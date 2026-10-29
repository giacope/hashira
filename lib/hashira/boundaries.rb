# frozen_string_literal: true

require "prism"

class Hashira::Boundaries
  class Declaration
    FIELDS = %w[root role entrypoint reason].freeze

    ROLE = "interpreted_model"

    private_constant :FIELDS, :ROLE

    def self.parse(record) = new(*FIELDS.map { record[it] })

    def initialize(root, role, entrypoint, reason)
      @root = root
      @role = role
      @entrypoint = entrypoint
      @reason = reason
    end

    def verify
      missing = FIELDS.zip(to_a).find { |_field, value| !present?(value) }
      raise(Hashira::Error, "boundary #{@root || "(unknown)"} #{missing.first} is missing") if missing
      raise(Hashira::Error, "boundary #{@root} has unknown role #{@role.inspect}") unless @role == ROLE
    end

    def to_a = [@root, @role, @entrypoint, @reason]

    private

    def present?(value) = value.is_a?(String) && !value.empty?
  end

  def initialize(records, trees, home = ".")
    @records = records
    @trees = trees
    @home = home
  end

  def interpreted
    return @_interpreted if @_interpreted
    verify
    @_interpreted = entries.map { it.to_a.fetch(0) }
  end

  private

  def entries = @_entries ||= @records.map { declaration(it) }

  def declaration(record)
    raise(Hashira::Error, "boundary declaration is not an object") unless record.is_a?(Hash)
    Hashira::Boundaries::Declaration.parse(record)
  end

  def verify
    entries.each do
      it.verify
      route(it)
    end
  end

  def route(entry)
    root, _role, entrypoint, _reason = entry.to_a
    files = calls(root)
    raise(Hashira::Error, "boundary #{root} has no root calls") if files.empty?
    bypasses = files.reject { same?(it, entrypoint) }
    raise(Hashira::Error, "boundary #{root} bypasses #{entrypoint}: #{bypasses.join(", ")}") unless bypasses.empty?
  end

  def calls(root)
    @trees.filter_map { |file, tree| file if Hashira::Analysis::NodeWalk.new(tree).collect.any? { invocation?(it, root) } }
  end

  def invocation?(node, root)
    node.is_a?(Prism::CallNode) && Hashira::Analysis::Syntax.new(node.receiver).segments.first == root
  end

  def same?(file, entrypoint) = File.expand_path(file) == File.expand_path(entrypoint, @home)
end
