# frozen_string_literal: true

class Evaluation::Record
  def initialize(board, results, corpus)
    @board = board
    @results = results
    @corpus = corpus
  end

  def print(io)
    @board.write(@results)
    @corpus.park
    io.puts(@board.markdown)
  end

  def status = @board.passed? ? 0 : 1
end
