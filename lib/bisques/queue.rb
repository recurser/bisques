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


    attr_reader :client # :nodoc:

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

    # Queues are created by the Client passing the client itself and the url
    # for the queue.
    def initialize(client, url)
      @client, @url = client, url
    end

    # The name of the queue derived from the URL.
    def name
      @url.split("/").last
    end

    # The path part of the queue URL
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
    def hash # :nodoc:
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
    # ==== Example with one attribute:
    #
    #   queue.attributes(:ApproximateNumberOfMessages) => 10
    #
    # ==== Example with multiple attributes:
    #
    #   queue.attributes(:ApproximateNumberOfMessages, :ApproximateNumberOfMessagesDelayed) => {:ApproximateNumberOfMessages => 10, :ApproximateNumberOfMessagesDelayed => 5}
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
    def delete
      client.delete_queue(url)
    end

    # Post a message to the queue. The message must be serializable (i.e.
    # strings, numbers, arrays, hashes).
    def post_message(object)
      client.send_message(url, JSON.dump(object))
    end

    # Retrieve a message from the queue. Returns nil if no message is waiting
    # in the given poll time. Otherwise it returns a Message.
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
    def delete_message(handle)
      response = client.delete_message(url, handle)
      response.success?
    end

    # Return a message to the queue after receiving it. This would typically
    # happen if the receiver decided it couldn't process.
    def return_message(handle)
      client.change_message_visibility(url, handle, 0)
    end
  end
end
