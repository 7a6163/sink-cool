# frozen_string_literal: true

module Sink
  class Page
    include Enumerable

    attr_reader :records, :cursor

    def initialize(records:, cursor: nil, complete: true)
      @records = records.freeze
      @cursor = cursor
      @complete = complete
    end

    def each(&) = @records.each(&)

    def complete? = !!@complete

    def more? = !complete? && !cursor.nil?

    def size = @records.size
    alias length size

    def empty? = @records.empty?

    def [](index) = @records[index]

    def inspect = "#<#{self.class} size=#{size} cursor=#{cursor.inspect} complete=#{complete?}>"
  end
end
