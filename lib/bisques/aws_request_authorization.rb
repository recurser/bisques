require "openssl"

module Bisques
  # Instances of this class are used to create HTTP authorization headers for
  # AWS using Signature Version 4, as per
  # http://docs.amazonwebservices.com/general/latest/gr/signature-version-4.html
  #
  # === Usage
  #
  # This is just an example of extracting the relevant information.
  # 
  #   url = "https://sqs.us-east-1.amazon.com/"
  #   original_headers = {"Content-Type": "text/plain"}
  #   query = {"Action" => "ListQueues"}
  #   body = "some body text"
  #   credentials = AwsCredentials.default
  #   
  #   authorization = AwsRequestAuthorization.new
  #   authorization.url = url
  #   authorization.method = "POST"
  #   authorization.query = query
  #   authorization.body = body
  #   authorization.region = "us-east-1"
  #   authorization.service = "sqs"
  #   authorization.headers = original_headers
  #
  #   new_headers = authorization.headers.merge(
  #     "Authorization" => authorization.authorization_header
  #   )
  #
  #   url_with_query = url + "?" + query.map{|p| p.join("=")}.join("&")
  #
  #   Net::HTTP.post(
  #     url_with_query,
  #     body,
  #     new_headers
  #   )
  #
  class AwsRequestAuthorization
    # The full URL to the API call.
    attr_accessor :url
    # The HTTP method.
    attr_accessor :method
    # A hash of key/pairs for the query string.
    attr_accessor :query
    # A string of the body being sent (for POST and PUT HTTP methods).
    attr_accessor :body
    # The AWS region.
    attr_accessor :region
    # The AWS service.
    attr_accessor :service
    # An AwsCredentials object.
    attr_accessor :credentials
    # The headers to read back.
    attr_reader   :headers

    # The generated authorization header.
    def authorization_header
      [
        "AWS4-HMAC-SHA256",
        "Credential=#{credentials.aws_key}/#{request_datestamp}/#{region}/#{service}/aws4_request,",
        "SignedHeaders=#{signed_headers.join(";")},",
        "Signature=#{signature.to_s}"
      ].join(" ")
    end

    # The HTTP headers being sent.
    def headers=(headers={})
      @headers = headers.merge(
        "x-amz-date" => request_timestamp
      )
    end

    private

    # When first called set a time for the request and keep it.
    def request_time
      @request_time ||= Time.now.utc
    end

    # The AWS timestamp format.
    def request_timestamp
      request_time.strftime("%Y%m%dT%H%M%SZ")
    end

    # The AWS datestamp format.
    def request_datestamp
      request_time.strftime("%Y%m%d")
    end

    # The digest used is SHA2.
    def digest
      Digest::SHA2.new
    end

    # Task 3: Calculate the signature.
    def signature
      digest = "SHA256"
      OpenSSL::HMAC.hexdigest(digest, signing_key, string_to_sign)
    end

    # Calculate the signing key for task 3.
    def signing_key
      digest = "SHA256"
      kDate = OpenSSL::HMAC.digest(digest, "AWS4" + credentials.aws_secret, request_datestamp)
      kRegion = OpenSSL::HMAC.digest(digest, kDate, region)
      kService = OpenSSL::HMAC.digest(digest, kRegion, service)
      OpenSSL::HMAC.digest(digest, kService, "aws4_request")
    end

    # Task 2: Create the string to sign.
    def string_to_sign
      [
        "AWS4-HMAC-SHA256",
        request_timestamp,
        credential_scope,
        digest.hexdigest(canonical)
      ].join("\n")
    end

    # Task 1: Create a canonical request.
    def canonical
      canonical = ""
      canonical << method.to_s.upcase << "\n"
      canonical << uri.path << "\n"

      canonical_query.each_with_index do |(param,value), index|
      canonical << param << "=" << value
      canonical << "&" unless index == query.size - 1
      end

      canonical << "\n"
      canonical << canonical_headers.map{|h| h.join(":")}.join("\n")
      canonical << "\n\n"
      canonical << signed_headers.join(";")
      canonical << "\n"

      canonical << digest.hexdigest(body.to_s).downcase
      canonical
    end

    # List of signed headers.
    def signed_headers
      canonical_headers.map{|name,value| name}
    end

    # Credential scope for task 2.
    def credential_scope
      [request_datestamp,
        region,
        service,
        "aws4_request"].join("/")
    end

    # Canonical query for task 1. Uses the AwsRequest::aws_encode for AWS
    # encoding rules.
    def canonical_query
      query.map{|param,value| [AwsRequest.aws_encode(param), AwsRequest.aws_encode(value)]}.sort
    end

    # The canonical headers, including the Host.
    def canonical_headers
      hash = headers.dup
      hash["host"] ||= Addressable::URI.parse(url).host
      hash = hash.map{|name,value| [name.downcase,value]}
      hash.reject!{|name,value| name == "authorization"}
      hash.sort
    end

    def uri
      Addressable::URI.parse(url)
    end
  end
end
