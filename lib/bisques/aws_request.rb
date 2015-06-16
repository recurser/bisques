require 'bisques/aws_request_authorization'
require 'bisques/aws_response'

module Bisques
  # A request to an AWS API call. This class must be initiated with a client
  # instance of HTTPClient. A number of mandatory attributes must be set before
  # calling {#make_request} to return the response. {#make_request} returns an
  # {AwsResponse} object.
  #
  # @example
  #
  #   request = AwsRequest.new(httpclient)
  #   request.method = "GET" or "POST"
  #   request.query = {"hash" => "of query params"}
  #   request.body = {"hash" => "of form params"} or "text body"
  #   request.headers = {"hash" => "of optional headers"}
  #   request.path = "optional path"
  #   request.region = "AWS region (ex. us-east-1)"
  #   request.service = "AWS service (ex. sqs)"
  #   request.credentials = AwsCredentials.new("aws_key", "aws_secret")
  #   response = request.make_request
  #
  class AwsRequest
    # @return [String] The HTTP method to use. Should be GET or POST.
    attr_accessor :method
    # @return [Hash] A hash describing the query params to send.
    attr_accessor :query
    # @return [Hash,String] A hash or string describing the form params or HTTP body. Only used when
    #   the method is POST or PUT.
    attr_accessor :body
    # @return [Hash] A hash of additional HTTP headers to send with the request.
    attr_accessor :headers
    # @return [String] The path to the API call. This shouldn't be the full URL as the host part
    #   is built from the region and service.
    attr_accessor :path
    # @return [String] The AWS region. Ex: us-east-1
    attr_accessor :region
    # @return [String] The AWS service. Ex: sqs
    attr_accessor :service
    # @return [AwsCredentials] The AWS credentials. Should respond to aws_key and aws_secret.
    attr_accessor :credentials

    # @return [AwsResponse] An AwsResponse object describing the response. Returns nil until
    #   {#make_request} has been called.
    attr_reader :response
    # @return [AwsRequestAuthorization]
    # @!visibility private
    attr_reader :authorization # :nodoc:

    # AWS has some particular rules about how it likes it's form params encoded.
    #
    # @param [String] value
    # @return [String] encoded value
    def self.aws_encode(value)
      value.to_s.gsub(/([^a-zA-Z0-9._~-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end
    end

    # Create a new {AwsRequest} using the given HTTPClient object.
    #
    # @param [HTTPClient] httpclient
    def initialize(httpclient)
      @httpclient = httpclient
    end

    # The full URL to the API endpoint the request will call.
    #
    # @return [String]
    def url
      File.join("https://#{service}.#{region}.amazonaws.com", path)
    end

    # Send the HTTP request and get a response. Returns an AwsResponse object.
    # The instance is frozen once this method is called and cannot be used
    # again.
    def make_request
      create_authorization

      options = {}
      options[:header] = authorization.headers.merge(
        'Authorization' => authorization.authorization_header
      )
      options[:query] = query if query.any?
      options[:body] = form_body if body

      Rails.logger.info "==========================================="
      Rails.logger.info method
      Rails.logger.info url
      Rails.logger.info options
      Rails.logger.info "==========================================="

      http_response = @httpclient.request(method, url, options)
      @response = AwsResponse.new(self, http_response)

      freeze

      @response
    end

    private

    # Encode the form params if the body is given as a Hash.
    def form_body
      if body.is_a?(Hash)
        body.map do |k,v|
          [AwsRequest.aws_encode(k), AwsRequest.aws_encode(v)].join("=")
        end.join("&")
      else
        body
      end
    end

    # Create the AwsRequestAuthorization object for the request.
    def create_authorization
      @authorization = AwsRequestAuthorization.new.tap do |authorization|
        authorization.url = url
        authorization.method = method
        authorization.query = query
        authorization.body = form_body
        authorization.region = region
        authorization.service = service
        authorization.credentials = credentials
        authorization.headers = headers
      end
    end
  end
end
