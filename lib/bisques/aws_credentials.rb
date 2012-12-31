module Bisques
  # Represents an AWS key/secret combination. Provides a convenient class
  # method for setting defaults that can be used by all objects later on.
  #
  # Example:
  #
  #   AwsCredentials.default('aws_key', 'aws_secret')
  #
  class AwsCredentials
    attr_reader :aws_key, :aws_secret

    def initialize(aws_key, aws_secret)
      @aws_key, @aws_secret = aws_key, aws_secret
    end

    class << self
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
