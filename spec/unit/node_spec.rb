require "spec_helper"

describe Raft::Node do
  describe "append_entries" do
    it "returns false if the given term is less than the node's current term" do
      node = Raft::Node.new("a")
      node.log << {:term => 2, :value => 10}
      node.current_term = 2

      result = node.append_entries(
        :term => 1,
        :leader_id => "b",
        :prev_log_index => 1,
        :prev_log_term => 1,
        :entries => ["42"],
        :leader_commit => 1
      )

      expect(result).to eq(:term => 2, :success => false)
    end

    it "returns false if log doesn't contain an entry at prev_log_index" do
      node = Raft::Node.new("a")
      node.current_term = 1

      result = node.append_entries(
        :term => 1,
        :leader_id => "b",
        :prev_log_index => 1,
        :prev_log_term => 1,
        :entries => ["42"],
        :leader_commit => 1
      )

      expect(result).to eq(:term => 1, :success => false)
    end

    it "returns false if log doesn't contain an entry at prev_log_index with prev_log_term" do
      node = Raft::Node.new("a")
      node.current_term = 2
      node.log << {:term => 1, :value => 10}

      result = node.append_entries(
        :term => 2,
        :leader_id => "b",
        :prev_log_index => 1,
        :prev_log_term => 2,
        :entries => ["42"],
        :leader_commit => 1
      )

      expect(result).to eq(:term => 2, :success => false)
    end

    it "appends new entries to an empty log" do
      node = Raft::Node.new("a")

      result = node.append_entries(
        :term => 1,
        :leader_id => "b",
        :prev_log_index => 0,
        :prev_log_term => 0,
        :entries => ["42"],
        :leader_commit => 1
      )

      expect(result).to eq(:term => 1, :success => true)
      expect(node.log).to eq([{:term => 1, :value => "42"}])
    end

    it "Removes entries existing past the current index" do
      node = Raft::Node.new("a")
      node.current_term = 1
      node.log << {:term => 1, :value => 10}
      node.log << {:term => 1, :value => 20}
      node.log << {:term => 1, :value => 30}
      node.log << {:term => 1, :value => 40}

      result = node.append_entries(
        :term => 2,
        :leader_id => "b",
        :prev_log_index => 1,
        :prev_log_term => 2,
        :entries => [15],
        :leader_commit => 1
      )

      expect(result).to eq(:term => 2, :success => false)
      expect(node.log).to eq([])
    end

    it "sets commit index = min(leaderCommit, index of last new entry)" do
      node = Raft::Node.new("a")
      node.current_term = 1
      node.commit_index = 0
      node.log << {:term => 1, :value => 10}
      node.log << {:term => 1, :value => 20}

      result = node.append_entries(
        :term => 1,
        :leader_id => "b",
        :prev_log_index => 2,
        :prev_log_term => 1,
        :entries => [15],
        :leader_commit => 2
      )

      expect(result).to eq(:term => 1, :success => true)
      expect(node.commit_index).to eq(2)
    end

    describe "applying to state machine" do
      it "applies indexes between lastApplied and commitIndex" do
        node = Raft::Node.new("a")
        node.current_term = 1
        node.log << {:term => 1, :value => 10}
        node.log << {:term => 1, :value => 10}
        node.log << {:term => 1, :value => 20}
        node.log << {:term => 1, :value => 20}

        node.append_entries(
          :term => 1,
          :leader_id => "b",
          :prev_log_index => 4,
          :prev_log_term => 1,
          :entries => [30],
          :leader_commit => 4
        )

        expect(node.state_machine.applied).to eq([10, 10, 20, 20])
        expect(node.last_applied).to eq(4)
        expect(node.commit_index).to eq(4)
      end

      it "applies indexes between lastApplied and commitIndex" do
        node = Raft::Node.new("a")
        node.current_term = 1
        node.last_applied = 2
        node.log << {:term => 1, :value => 10}
        node.log << {:term => 1, :value => 10}
        node.log << {:term => 1, :value => 20}
        node.log << {:term => 1, :value => 20}

        node.append_entries(
          :term => 1,
          :leader_id => "b",
          :prev_log_index => 4,
          :prev_log_term => 1,
          :entries => [30],
          :leader_commit => 4
        )

        expect(node.state_machine.applied).to eq([20, 20])
        expect(node.last_applied).to eq(4)
        expect(node.commit_index).to eq(4)
      end
    end

    it "transitions to follower if a request with a larger term is received" do
      node = Raft::Node.new("a")
      node.status = Raft::Status::Leader
      node.current_term = 1

      node.append_entries(
        :term => 2,
        :leader_id => "b",
        :prev_log_index => 4,
        :prev_log_term => 1,
        :entries => [30],
        :leader_commit => 4
      )

      expect(node.status).to eq(Raft::Status::Follower)
      expect(node.voted_for).to be_nil
    end
  end

  describe "request_vote" do
    it "doesn't vote in old terms" do
      node = Raft::Node.new("a")
      node.current_term = 2
      node.log << {:term => 2, :value => 10}

      result = node.request_vote(
        :term => 1,
        :candidate_id => "b",
        :last_log_index => 1,
        :last_log_term => 1
      )

      expect(result).to eq({:term => 2, :vote_granted => false})
      expect(node.voted_for).to be_nil
    end

    it "grants a vote if voted_for = nil and candidate log is up to date as receiver" do
      node = Raft::Node.new("a")
      node.current_term = 2
      node.log << {:term => 2, :value => 10}

      result = node.request_vote(
        :term => 3,
        :candidate_id => "b",
        :last_log_index => 1,
        :last_log_term => 2
      )

      expect(result).to eq({:term => 3, :vote_granted => true})
      expect(node.voted_for).to eq("b")
    end

    it "grants a vote if voted_for = nil and log is empty" do
      node = Raft::Node.new("a")
      node.current_term = 1

      result = node.request_vote(
        :term => 2,
        :candidate_id => "b",
        :last_log_index => 1,
        :last_log_term => 2
      )

      expect(result).to eq({:term => 2, :vote_granted => true})
      expect(node.voted_for).to eq("b")
    end

    it "doesn't grant vote if candidate's log is not up to date with receiver" do
      node = Raft::Node.new("a")
      node.current_term = 1
      node.log << {:term => 1, :value => 10}
      node.log << {:term => 1, :value => 20}
      node.log << {:term => 1, :value => 30}
      node.log << {:term => 1, :value => 40}

      result = node.request_vote(
        :term => 2,
        :candidate_id => "b",
        :last_log_index => 1,
        :last_log_term => 1
      )

      expect(result).to eq({:term => 2, :vote_granted => false})
      expect(node.voted_for).to be_nil
    end

    it "transitions to follower if a request with a larger term is received" do
      node = Raft::Node.new("a")
      node.status = Raft::Status::Leader
      node.current_term = 1

      node.request_vote(
        :term => 2,
        :candidate_id => "b",
        :last_log_index => 1,
        :last_log_term => 1
      )

      expect(node.status).to eq(Raft::Status::Follower)
      expect(node.voted_for).to eq("b")
    end
  end
end
