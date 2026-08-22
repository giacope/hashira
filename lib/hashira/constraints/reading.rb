# frozen_string_literal: true

require "yaml"

class Hashira::Constraints::Reading
  FILE = ".hashira.yml"

  Verdict = Data.define(:list, :trouble)

  def initialize(path)
    @path = path
  end

  def declarations = Hashira::Constraints::Declarations.new(verdict.list)

  def trouble = verdict.trouble

  private

  def verdict = @_verdict ||= catch(:refused) { Verdict.new(list: parsed, trouble: nil) }

  def parsed = entries.map { declare(it) }.uniq

  def entries
    listed = document.fetch("constraints", [])
    listed.is_a?(Array) ? listed : refuse("constraints: must be a list of entries, not #{kind(listed)}")
  end

  def document
    return {} unless File.exist?(@path)
    read.is_a?(Hash) ? read : refuse("its top level must be a mapping of settings, not #{kind(read)}")
  end

  def read
    @_read ||= YAML.safe_load_file(@path) || {}
  rescue Psych::SyntaxError, SystemCallError => error
    refuse("#{error.message.lines.first.strip} — hashira reads it as YAML")
  end

  def declare(entry)
    refuse("each constraint must be a mapping with a fact: and a scope:") unless entry.is_a?(Hash)
    Hashira::Constraints::Declaration.new(name: fact(entry["fact"]), scope: scope(entry["scope"]))
  end

  def fact(given)
    name = given.to_s.to_sym
    Hashira::Constraints::Vocabulary.known?(name) ? name : refuse(unknown(given))
  end

  def unknown(given) = "unknown fact #{given.inspect} — hashira knows #{Hashira::Constraints::Vocabulary.listed}"

  def scope(given)
    shown = given.inspect
    trimmed = given.to_s.delete_suffix("/")
    refuse("scope #{shown} must name a path inside the project") unless inside?(trimmed)
    refuse("scope #{shown} is not a directory") unless Dir.exist?(trimmed)
    trimmed
  end

  def inside?(scope) = !scope.empty? && !scope.start_with?("/") && !scope.split("/").include?("..")

  def kind(given) = given.class.name.downcase

  def refuse(reason) = throw(:refused, Verdict.new(list: [], trouble: "#{@path}: #{reason}"))
end
