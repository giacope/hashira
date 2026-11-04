# frozen_string_literal: true

module Hashira::CLI
  class Flag
    class Switch
      def initialize(name)
        @name = name
      end

      def read(arguments) = arguments.drop(@name)

      def label = @name

      def to_s = @name
    end

    class Value
      def initialize(name, argument, parse = Hashira::CLI::Flag::Verbatim.new, default = "")
        @name = name
        @argument = argument
        @parse = parse
        @default = default
      end

      def read(arguments) = @parse.parse(arguments.take(@name, @default))

      def label = "#{@name} #{@argument}"

      def to_s = @name
    end

    class Verbatim
      def parse(raw) = raw
    end

    UNSET = [nil, []].freeze

    private_constant :UNSET

    def initialize(text, reading, modes = [])
      @text = text
      @reading = reading
      @modes = modes
    end

    def read(arguments) = @reading.read(arguments)

    def bid(value)
      return [] if UNSET.include?(value)
      @modes.map { it == :parsed ? ["#{@reading} #{value}", value] : [@reading.to_s, it] }
    end

    def named?(name) = @reading.to_s == name

    def to_s
      first, *rest = @text
      ["  #{@reading.label.ljust(21)}#{first}\n", *rest.map { "#{" " * 23}#{it}\n" }].join
    end
  end

  class Page
    def initialize(name, mode, text, flag = Hashira::CLI::Flag.new(text, Hashira::CLI::Flag::Switch.new(name)))
      @name = name
      @mode = mode
      @flag = flag
    end

    def seen?(arguments) = @name.split(", ").any? { arguments.drop(it) }

    def configured(_settings) = self

    def status(usage, _notices)
      usage.public_send(@mode)
      usage.status
    end

    def to_s = @flag.to_s

    def to_h = { mode: @mode }
  end
end
