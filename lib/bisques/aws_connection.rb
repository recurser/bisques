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
  # must pass the correct params via super from it's #initialize call. Two
  # useful methods are added to the including class, #request and #action.
  module AwsConnection
    def self.included(mod) # :nodoc:
      mod.class_eval do
        attr_accessor :credentials, :region, :service
      end
    end

    # Give the region, service and optionally the AwsCredentials.
    #
    # === Example:
    #
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

    def connection # :nodoc:
      @connection ||= HTTPClient.new.tap do |http|
        http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.receive_timeout = 30
      end
    end

    # Perform an HTTP query to the given path using the given method (GET,
    # POST, PUT, DELETE). A hash of query params can be specified. A POST or
    # PUT body cna be specified as either a string or a hash of form params. A
    # hash of HTTP headers can be specified.
    def request(method, path, query = {}, body = nil, headers = {})
      AwsRequest.new(connection).tap do |aws_request|
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
    # of options can be passed as arguments for the API call. Returns an
    # AwsResponse. If the response is not successful then an AwsActionError is
    # raised and the error information is extracted into the exception
    # instance.
    #
    # The API call will be automatically retried if the returned status code is
    # in the 500 range.
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
  end
end
