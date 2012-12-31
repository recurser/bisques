require 'bisques/queue'
require 'thread'

module Bisques
  # Listen for messages on a queue and execute a block when they arrive.
  class QueueListener
    # @param [Queue] queue the queue to listen on
    # @param [Fixnum] poll_time the number of seconds to long poll during each iteration. Maximum is 20.
    def initialize(queue, poll_time = 5)
      @queue, @poll_time = queue, poll_time
    end

    # @return [Boolean] returns true while the listener is active.
    def listening?
      @listening
    end

    # Listen for messages. This is asynchronous and returns immediately.
    #
    # @example
    #
    #   queue = bisques.find_or_create_queue("my queue")
    #   listener = QueuedListener.new(queue)
    #   listener.listen do |message|
    #     puts "Received #{message.object}"
    #     message.delete
    #   end
    #
    #   while true; sleep 1; end # Process messages forever
    #
    # @note Note that the block you give to this method is executed in a new thread.
    # @yield [Message] a message received from the {Queue}
    #
    def listen(&block)
      return if @listening
      @listening = true

      @thread = Thread.new do
        while @listening
          message = @queue.retrieve(@poll_time)
          block.call(message) if message.present?
        end
      end
    end

    # Stop listening for messages.
    def stop
      @listening = false
      @thread.join if @thread
    end
  end

  # Listen for messages on several queues at the same time. The interface for
  # objects of this class is identical to that of {QueueListener}.
  #
  # @example
  #
  #   queue_1 = bisques.find_or_create_queue("queue one")
  #   queue_2 = bisques.find_or_create_queue("queue two")
  #   listener = MultiQueueListener.new(queue_1, queue_2)
  #   listener.listen do |message|
  #     puts "Queue #{message.queue.name}, message #{message.object}"
  #     message.delete
  #   end
  #   while true; sleep 1; end # Process messages forever
  #
  class MultiQueueListener
    # @param [Array<Queue>] queues
    def initialize(*queues)
      @queues = queues
      @listeners = []
    end

    # (see QueueListener#listening?)
    def listening?
      @listeners.any?
    end

    # (see QueueListener#listen)
    def listen(&block)
      return if @listeners.any?
      @listeners = @queues.map do |queue|
        QueueListener.new(queue)
      end

      @listeners.each do |listener|
        listener.listen(&block)
      end
    end

    # (see QueueListener#stop)
    def stop
      @listeners.each(&:stop)
      @listeners = []
    end
  end
end
