require 'json'

module Bisques
  # A message received from an SQS queue.
  class Message
    # The queue this message originated from.
    attr_reader :queue
    # The AWS Id of the message.
    attr_reader :id
    # A unique handle used to manipulate the message.
    attr_reader :handle
    # The raw text body of the message.
    attr_reader :body
    # Hash of SQS attributes.
    attr_reader :attributes

    def initialize(queue, id, handle, body, attributes = {}) #:nodoc:
      @queue, @id, @handle, @body, @attributes = queue, id, handle, body, attributes
    end

    # The deserialized object in the message. This method is used to retrieve
    # the contents that Queue#post_message placed there.
    #
    # Example:
    #
    #   queue.post_message([1,2,3])
    #   queue.retrieve.object => [1,2,3]
    #
    def object
      @object ||= JSON.parse(body)
    end

    # Delete the message from the queue. This should be called after the
    # message has been received and processed. If not then after a timeout the
    # message will get added back to the queue.
    def delete
      queue.delete_message(handle)
    end

    # Return the message to the queue immediately. If a client has taken a
    # message and cannot process it for any reason it can put the message back
    # faster than the default timeout by calling this method.
    def return
      queue.return_message(handle)
    end
  end
end
