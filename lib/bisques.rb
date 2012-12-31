# See {file:README README}
module Bisques
  class Error < StandardError; end
  class MessageHasWrongMd5Error < Error
    attr_reader :msg, :expected, :got

    def initialize(msg, expected, got)
      @msg, @expected, @got = msg, expected, got
      super(msg)
    end
  end
end

require 'bisques/client'
