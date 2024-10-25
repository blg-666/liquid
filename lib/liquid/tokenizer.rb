# frozen_string_literal: true

require "strscan"

module Liquid
  class Tokenizer
    attr_reader :line_number, :for_liquid_tag

    TAG_END = /%\}/
    TAG_OR_VARIABLE_START = /\{[\{\%}]/
    NEWLINE = /\n/

    OPEN_CURLEY = 123
    CLOSE_CURLEY = 125
    PERCENTAGE = 37

    def initialize(source, line_numbers = false, line_number: nil, for_liquid_tag: false)
      @line_number    = line_number || (line_numbers ? 1 : nil)
      @for_liquid_tag = for_liquid_tag
      @ss = StringScanner.new(source)
    end

    def shift
      return nil if @ss.eos?

      token = @for_liquid_tag ? next_liquid_token : next_token

      return nil unless token

      if @line_number
        @line_number += @for_liquid_tag ? 1 : token.count("\n")
      end

      token
    end

    private

    def next_liquid_token
      # read until we find a \n
      start = @ss.pos
      if @ss.scan_until(NEWLINE).nil?
        token = @ss.rest
        @ss.terminate
        return token
      end

      @ss.string.byteslice(start, @ss.pos - start - 1)
    end

    def next_token
      # possible states: :text, :tag, :variable
      c_list = @ss.peek(2)

      case c_list
      when "{%"
        next_tag_token
      when "{{"
        next_variable_token
      else
        next_text_token
      end
    end

    def next_text_token
      start = @ss.pos

      unless @ss.skip_until(TAG_OR_VARIABLE_START)
        token = @ss.rest
        @ss.terminate
        return token
      end

      @ss.pos -= 2
      @ss.string.byteslice(start, @ss.pos - start)
    end

    def next_variable_token
      start = @ss.pos
      @ss.pos += 2

      # it is possible to see a {% before a }} so we need to check for that
      byte_a = @ss.scan_byte

      until @ss.eos?
        while byte_a != OPEN_CURLEY && byte_a != CLOSE_CURLEY && @ss.eos? == false
          byte_a = @ss.scan_byte
        end

        break if @ss.eos?

        byte_b = @ss.scan_byte

        if byte_b != CLOSE_CURLEY && byte_b != PERCENTAGE
          byte_a = byte_b
          next
        end

        if byte_a == CLOSE_CURLEY && byte_b == CLOSE_CURLEY
          return @ss.string.byteslice(start, @ss.pos - start)
        elsif byte_a == OPEN_CURLEY && byte_b == PERCENTAGE
          return next_tag_token(start)
        end
      end

      return "{{"
    end

    def next_tag_token(start = nil)
      start ||= @ss.pos
      @ss.pos += 2

      @ss.scan_until(TAG_END)

      @ss.string.byteslice(start, @ss.pos - start)
    end

    def raise_syntax_error(message)
      raise SyntaxError, message
    end
  end
end
