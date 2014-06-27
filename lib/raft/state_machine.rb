module Raft
  class StateMachine
    def initialize
      @committed = []
    end

    def apply(value)
      @committed << value
    end

    def applied
      @committed
    end
  end
end
