require 'httpclient'
require 'bisques/aws_request'
require 'bisques/aws_credentials'

module Bisques
  class AwsActionError < Bisques::Error
    attr_reader :type, :code, :message, :status

    def initialize(type, code, message, status)
      @type, @code, @message, @status = type, code, message, status
      super(message)
    end

    def to_s
      "HTTP #{status}: #{type} #{code} #{message}"
    end
  end

  # This module is for making API classes more convenient. The including class
  # must pass the correct params via super from it's {#initialize} call. Two
  # useful methods are added to the including class, {#request} and {#action}.
  #
  # @example
  #   class Sqs
  #     include AwsConnection
  #
  #     def initialize(region)
  #       super(region, 'sqs')
  #     end
  #   end
  # 
  module AwsConnection
    # @!visibility private
    def self.included(mod) # :nodoc:
      mod.class_eval do
        attr_accessor :credentials, :region, :service
      end
    end

    # Give the region, service and optionally the AwsCredentials.
    #
    # @param [String] region the AWS region (ex. us-east-1)
    # @param [String] service the AWS service (ex. sqs)
    # @param [AwsCredentials] credentials
    #
    # @example
    #   class Sqs
    #     include AwsConnection
    #
    #     def initialize(region)
    #       super(region, 'sqs')
    #     end
    #   end
    #
    def initialize(region, service, credentials = AwsCredentials.default)
      @region, @service, @credentials = region, service, credentials
    end

    # Perform an HTTP query to the given path using the given method (GET,
    # POST, PUT, DELETE). A hash of query params can be specified. A POST or
    # PUT body cna be specified as either a string or a hash of form params. A
    # hash of HTTP headers can be specified.
    #
    # @param [String] method HTTP method, should be GET, POST, PUT or DELETE
    # @param [String] path
    # @param [Hash] query HTTP query params to send. Specify these as a hash, do not append them to the path.
    # @param [Hash,#to_s] body HTTP request body. This can be form data as a hash or a String. Only applies to POST and PUT HTTP methods.
    # @param [Hash] headers additional HTTP headers to send.
    # @return [AwsRequest]
    def request(method, path, query = {}, body = nil, headers = {})
      AwsRequest.new(aws_http_connection).tap do |aws_request|
        aws_request.credentials = credentials
        aws_request.path = path
        aws_request.region = region
        aws_request.service = service
        aws_request.method = method
        aws_request.query = query
        aws_request.body = body
        aws_request.headers = headers
        aws_request.make_request
      end
    end

    # Call an AWS API with the given name at the given path. An optional hash
    # of options can be passed as arguments for the API call. 
    # 
    # @note The API call will be automatically retried *once* if the returned status code is
    #   in the 500 range.
    #
    # @param [String] action_name
    # @param [String] path
    # @param [Hash] options
    # @return [AwsResponse]
    # @raise [AwsActionError] if the response is not successful. AWS error
    #   information can be extracted from the exception.
    def action(action_name, path = "/", options = {})
      retries = 0

      begin
        # If options given in place of path assume /
        options, path = path, "/" if path.is_a?(Hash) && options.empty?
        request(:post, path, {}, options.merge("Action" => action_name)).response.tap do |response|
          unless response.success?
            element = response.doc.xpath("//Error")
            raise AwsActionError.new(element.xpath("Type").text, element.xpath("Code").text, element.xpath("Message").text, response.http_response.status)
          end
        end
      rescue AwsActionError => e
        if retries < 2 && (500..599).include?(e.status.to_i)
          retries += 1
          retry
        else
          raise e
        end
      end
    end

    # Ignore the http connection when marshalling
    def marshal_dump
      [@region, @service, @credentials]
    end

    def marshal_load array
      @region, @service, @credentials = array
    end

    private
    def aws_http_connection
      @aws_http_connection ||= HTTPClient.new.tap do |http|
        http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.receive_timeout = 30
      end
    end
  end
end
