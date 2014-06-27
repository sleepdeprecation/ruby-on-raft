module Raft
  class Log
    extend Forwardable
    def_delegators :@log, :length, :<<, :last, :empty?

    def initialize
      @log = []
    end

    def [](i)
      @log[i - 1]
    end

    def []=(i, x)
      @log[i - 1] = x
    end

    def truncate_from!(i)
      @log.slice!((i - 1)..length)
      self
    end

    def to_a
      @log
    end

    def append_entries(term, entries)
      entries.each do |entry|
        @log << {:term => term, :value => entry}
      end
    end

    def ==(other_obj)
      if other_obj.class == Array
        @log == other_obj
      else
        super(other_obj)
      end
    end

    def do_on(start_index, end_index, &block)
      @log.slice(start_index...end_index).each do |entry|
        block.call(entry)
      end
    end
  end
end
