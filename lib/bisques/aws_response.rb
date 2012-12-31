require 'nokogiri'

module Bisques
  # Created by an AwsRequest to represent the returned details. The original
  # request is stored in {#request}. The raw content is available in {#content}.
  # AWS returns XML, and a Nokogiri::XML instance is available in {#doc}.
  class AwsResponse
    # @return [AwsRequest] The original AwsRequest that created this response.
    attr_reader :request
    # @return [String] The raw response string from AWS
    attr_reader :content
    # @return [#body,#status,#header] The HTTP response. This can be used to get any headers or status codes.
    attr_reader :http_response

    def initialize(request, http_response) # :nodoc:
      @request = request
      @http_response = http_response
      @content = @http_response.body
    end

    # A Nokogiri::XML document parsed from the {#content}.
    #
    # @return [Nokogiri::XML] XML document
    def doc
      @doc ||= Nokogiri::XML(content).tap{|x|x.remove_namespaces!}
    end

    # @return [Boolean] Returns true if the request was successful.
    def success?
      @http_response.ok?
    end

    # @return [String] The request ID from AWS.
    def request_id
      @http_response.header['x-amzn-RequestId']
    end
  end
end
