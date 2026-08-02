# frozen_string_literal: true

module RuboCop
  module Cop
    module Hashira
      class NoComments < Base
        extend AutoCorrector

        MSG = "Say it in the code: rename it, extract it, or name the constant."

        MAGIC = /\A#\s*(frozen_string_literal|encoding|coding|warn_indent|shareable_constant_value):/
        DIRECTIVE = /\A#\s*(rubocop|simplecov|rbs|steep|sorbet|typed):/
        NOTICE = /^#\s*(copyright\b|\(c\)\s*\d|spdx-|licen[sc]ed under\b|licen[sc]e:|all rights reserved)/i

        def on_new_investigation
          header = notice_header
          processed_source.comments.each { register(it) unless exempt?(it) || header.include?(it) }
        end

        private

        def exempt?(comment)
          text = comment.text
          MAGIC.match?(text) || DIRECTIVE.match?(text) || NOTICE.match?(text)
        end

        def notice_header
          header = header_comments
          NOTICE.match?(header.map(&:text).join("\n")) ? header : []
        end

        def header_comments
          first_code_line = processed_source.ast&.first_line || Float::INFINITY
          processed_source.comments.take_while { it.source_range.line < first_code_line }
        end

        def register(comment)
          add_offense(comment) { |corrector| corrector.remove(removal(comment)) }
        end

        def removal(comment)
          range = comment.source_range
          alone_on_line?(range) ? whole_line(range) : trailing(range)
        end

        def alone_on_line?(range) = range.source_line[0, range.column].strip.empty?

        def whole_line(range)
          finish = range.end_pos
          finish += 1 if processed_source.buffer.source[finish] == "\n"
          range.with(begin_pos: range.begin_pos - range.column, end_pos: finish)
        end

        def trailing(range)
          gap = range.source_line[0, range.column][/\s*\z/].length
          range.with(begin_pos: range.begin_pos - gap)
        end
      end
    end
  end
end
