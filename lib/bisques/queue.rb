require 'bisques/message'

module Bisques
  # An SQS queue
  class Queue
    class QueueError < Bisques::Error
      def initialize(queue, message)
        @queue = queue
        super("queue: #{queue.name}; #{message}")
      end
    end
    class QueueNotFound < QueueError; end

    # @!visibility private
    attr_reader :client # :nodoc:

    # @!visibility private
    def self.sanitize_name(name)
      name = name.gsub(/[^_\w\d]/, "")

      if name.length > 80
        short_name = name[0,75]
        short_name << Digest::MD5.hexdigest(name)
        short_name = short_name[0,80]
        name = short_name
      end

      name
    end

    # Queues are created by the {Client} passing the client itself and the url
    # for the queue.
    #
    # @param [Client] client
    # @param [String] url
    def initialize(client, url)
      @client, @url = client, url
    end

    # @return [String] The name of the queue derived from the URL.
    def name
      @url.split("/").last
    end

    # @return [String] The path part of the queue URL
    def path
      Addressable::URI.parse(@url).path
    end
    alias_method :url, :path

    def eql?(queue)
      hash == queue.hash
    end
    def ==(queue)
      hash == queue.hash
    end
    def hash
      @url.hash
    end

    # Return attributes for the queue. Pass in the names of the attributes to
    # retrieve, or :All for all attributes. The available attributes can be
    # found at
    # http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/Query_QueryGetQueueAttributes.html
    #
    # If 1 attribute is requested then just that attributes value is returned.
    # If more than one, or all, attributes are requested then a hash of
    # attribute names and values is returned.
    #
    # @param [String] attributes
    # @return [Object,Hash]
    #
    # @example with one attribute
    #
    #   queue.attributes(:ApproximateNumberOfMessages) == 10
    #
    # @example with multiple attributes
    #
    #   queue.attributes(:ApproximateNumberOfMessages, :ApproximateNumberOfMessagesDelayed) == {:ApproximateNumberOfMessages => 10, :ApproximateNumberOfMessagesDelayed => 5}
    #
    def attributes(*attributes)
      return nil if attributes.blank?

      values = {}
      response = client.get_queue_attributes(url, attributes)

      response.doc.xpath("//Attribute").each do |attribute_element|
        name = attribute_element.xpath("Name").text
        value = attribute_element.xpath("Value").text
        value = value.to_i if value =~ /\A\d+\z/
        values[name] = value
      end

      if values.size == 1 && attributes.size == 1
        values.values.first
      else
        values
      end
    end

    # Delete the queue
    # @return [AwsResponse]
    # @raise [AwsActionError]
    def delete
      client.delete_queue(url)
    end

    # Post a message to the queue. The message must be serializable (i.e.
    # strings, numbers, arrays, hashes).
    #
    # @param [String,Fixnum,Array,Hash] object
    # @raise [MessageHasWrongMd5Error]
    # @raise [AwsActionError]
    def post_message(object)
      client.send_message(url, JSON.dump(object))
    end

    def post_messages(objects)
      objects = objects.dup
      group = []
      while objects.any?
        group.push objects.pop

        if group.length == 10
          client.send_message_batch(url, objects.map{|obj| JSON.dump(obj)})
        end
      end

      if group.length > 0
        client.send_message_batch(url, objects.map{|obj| JSON.dump(obj)})
      end

      nil
    end

    # Retrieve a message from the queue. Returns nil if no message is waiting
    # in the given poll time. Otherwise it returns a Message.
    #
    # @param [Fixnum] poll_time
    # @return [Message,nil]
    # @raise [AwsActionError]
    def retrieve(poll_time = 1)
      response = client.receive_message(url, {"WaitTimeSeconds" => poll_time, "MaxNumberOfMessages" => 1})
      raise QueueNotFound.new(self, "not found at #{url}") if response.http_response.status == 404

      response.doc.xpath("//Message").map do |element|
        attributes = Hash[*element.xpath("Attribute").map do |attr_element|
          [attr_element.xpath("Name").text, attr_element.xpath("Value").text]
        end.flatten]

        Message.new(self, element.xpath("MessageId").text,
                    element.xpath("ReceiptHandle").text,
                    element.xpath("Body").text,
                    attributes
                   )
      end.first
    end

    # Retrieve a single message from the queue. This will block until a message
    # arrives. The message will be of the class Message.
    #
    # @param [Fixnum] poll_time
    # @return [Message]
    # @raise [AwsActionError]
    def retrieve_one(poll_time = 5)
      object = nil
      while object.nil?
        object = retrieve(poll_time)
      end
      object
    end

    # Delete a message from the queue. This should be called to confirm that
    # the message has been processed. If it is not called then the message will
    # get put back on the queue after a timeout.
    #
    # @param [String] handle
    # @return [Boolean] true if the message was deleted.
    # @raise [AwsActionError]
    def delete_message(handle)
      response = client.delete_message(url, handle)
      response.success?
    end

    # Return a message to the queue after receiving it. This would typically
    # happen if the receiver decided it couldn't process.
    #
    # @param [String] handle
    # @return [AwsResponse]
    # @raise [AwsActionError]
    def return_message(handle, time = 0)
      client.change_message_visibility(url, handle, time)
    end
  end
end
