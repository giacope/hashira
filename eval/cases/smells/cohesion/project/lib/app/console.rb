module App
  class Console
    COMMANDS = { "create" => :create, "review" => :review, "help" => :help }.freeze

    def initialize(io, errors)
      @io = io
      @errors = errors
    end

    def run(name, rest) = __send__(COMMANDS.fetch(name) { return missing(name) }, rest)
    def missing(name) = @errors.puts("unknown command #{name}")
    def warn(text) = @errors.puts(text)
    def help(_rest) = @io.puts("usage")
    def create(rest) = @io.puts("created #{rest.size}")
    def review(rest) = @io.puts("reviewed #{rest.size}")
  end
end
