# frozen_string_literal: true

module Liquid
  class Parser
    Kwarg = Struct.new(:name, :value)
    Arg = Struct.new(:value)

    def initialize(input)
      l       = Lexer.new(input)
      @tokens = l.tokenize
      @p      = 0 # pointer to current location
    end

    def jump(point)
      @p = point
    end

    def consume(type = nil)
      token = @tokens[@p]
      if type && token[0] != type
        raise SyntaxError, "Expected #{type} but found #{@tokens[@p].first}"
      end
      @p += 1
      token[1]
    end

    # Only consumes the token if it matches the type
    # Returns the token's contents if it was consumed
    # or false otherwise.
    def consume?(type)
      token = @tokens[@p]
      return false unless token && token[0] == type
      @p += 1
      token[1]
    end

    # Like consume? Except for an :id token of a certain name
    def id?(str)
      token = @tokens[@p]
      return false unless token && token[0] == :id
      return false unless token[1] == str
      @p += 1
      token[1]
    end

    def look(type, ahead = 0)
      tok = @tokens[@p + ahead]
      return false unless tok
      tok[0] == type
    end

    def expression
      token = @tokens[@p]
      case token[0]
      when :id
        name = consume
        lookups = variable_lookups
        command_flags = 0
        lookups.each_index do |i|
          if VariableLookup::COMMAND_METHODS.include?(lookups[i])
            @command_flags |= 1 << i
          end
        end
        VariableLookup.new_with(name, lookups, command_flags)
      when :open_square
        str = consume
        str << expression
        str << consume(:close_square)
        str << variable_lookups
      when :string, :number
        consume
      when :open_round
        consume
        first = expression
        consume(:dotdot)
        last = expression
        consume(:close_round)
        "(#{first}..#{last})"
      else
        raise SyntaxError, "#{token} is not a valid expression"
      end
    end

    def argument
      # might be a keyword argument (identifier: expression)
      if look(:id) && look(:colon, 1)
        name = consume(:id)
        consume(:colon)
        value = expression
        Kwarg.new(name, value)
      else
        Arg.new(expression)
      end
    end

    def variable_lookups
      lookups = []
      loop do
        if look(:open_square)
          consume
          lookups << expression
          consume(:close_square)
        elsif look(:dot)
          consume
          lookups << consume(:id)
        else
          break
        end
      end
      lookups
    end
  end
end
