# frozen_string_literal: true

require "prism"

class Hashira::Boundaries
  ROLE = "interpreted_model"

  Declaration =
    Data.define(:root, :role, :entrypoint, :reason) do
      def verify
        missing = members.find { !present?(public_send(it)) }
        root, role, _entrypoint, _reason = deconstruct
        raise(Hashira::Error, "boundary #{root || "(unknown)"} #{missing} is missing") if missing
        raise(Hashira::Error, "boundary #{root} has unknown role #{role.inspect}") unless role == Hashira::Boundaries::ROLE
      end
      private
      def present?(value) = value.is_a?(String) && !value.empty?
    end

  def initialize(records, trees)
    @records = records
    @trees = trees
  end

  def interpreted = @_interpreted ||= entries.each { check(it) }.map(&:root)

  private

  def entries = @_entries ||= @records.map { declaration(it) }

  def declaration(record)
    raise(Hashira::Error, "boundary declaration is not an object") unless record.is_a?(Hash)
    Declaration.new(*%w[root role entrypoint reason].map { record[it] })
  end

  def check(entry)
    entry.verify
    route(entry)
  end

  def route(entry)
    root, _role, entrypoint, _reason = entry.deconstruct
    files = calls(root)
    raise(Hashira::Error, "boundary #{root} has no root calls") if files.empty?
    bypasses = files.reject { same?(it, entrypoint) }
    raise(Hashira::Error, "boundary #{root} bypasses #{entrypoint}: #{bypasses.join(", ")}") unless bypasses.empty?
  end

  def calls(root)
    @trees.filter_map { |file, tree| file if Hashira::Analysis::NodeWalk.collect(tree).any? { invocation?(it, root) } }
  end

  def invocation?(node, root)
    node.is_a?(Prism::CallNode) && Hashira::Analysis::Syntax.segments(node.receiver).first == root
  end

  def same?(file, entrypoint) = File.expand_path(file) == File.expand_path(entrypoint)
end
