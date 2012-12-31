require 'json'

module Bisques
  # A message received from an SQS queue.
  class Message
    # @return [Queue] The queue this message originated from.
    attr_reader :queue
    # @return [String] The AWS Id of the message.
    attr_reader :id
    # @return [String] A unique handle used to manipulate the message.
    attr_reader :handle
    # @return [String] The raw text body of the message.
    attr_reader :body
    # @return [Hash] Hash of SQS attributes.
    attr_reader :attributes

    # @api
    # @param [Queue] queue
    # @param [String] id
    # @param [String] handle
    # @param [String] body
    # @param [Hash] attributes
    def initialize(queue, id, handle, body, attributes = {}) #:nodoc:
      @queue, @id, @handle, @body, @attributes = queue, id, handle, body, attributes
    end

    # The deserialized object in the message. This method is used to retrieve
    # the contents that Queue#post_message placed there.
    #
    # @example
    #
    #   queue.post_message([1,2,3])
    #   queue.retrieve.object == [1,2,3]
    #
    def object
      @object ||= JSON.parse(body)
    end

    # @return (see Queue#delete_message)
    # @raise (see Queue#delete_message)
    # Delete the message from the queue. This should be called after the
    # message has been received and processed. If not then after a timeout the
    # message will get added back to the queue.
    def delete
      queue.delete_message(handle)
    end

    # @return (see Queue#return_message)
    # @raise (see Queue#return_message)
    # Return the message to the queue immediately. If a client has taken a
    # message and cannot process it for any reason it can put the message back
    # faster than the default timeout by calling this method.
    def return
      queue.return_message(handle)
    end
  end
end
