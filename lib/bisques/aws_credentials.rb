module Bisques
  # Represents an AWS key/secret combination. Provides a convenient class
  # method for setting defaults that can be used by all objects later on.
  #
  # @example
  #
  #   AwsCredentials.default('aws_key', 'aws_secret')
  #
  class AwsCredentials
    # @return [String]
    attr_reader :aws_key, :aws_secret

    # @param [String] aws_key
    # @param [String] aws_secret
    def initialize(aws_key, aws_secret)
      @aws_key, @aws_secret = aws_key, aws_secret
    end

    class << self
      # (see #initialize)
      # Set or retrieve the default credentials
      def default(*args)
        if args.size == 2
          @default = AwsCredentials.new(*args)
        elsif args.empty?
          @default
        else
          raise ArgumentError, "default takes 0 or 2 arguments"
        end
      end
    end
  end
end
