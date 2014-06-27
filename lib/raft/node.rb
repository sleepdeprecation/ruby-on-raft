module Raft
  class Node
    attr_accessor :current_term,
      :voted_for,
      :log,
      :commit_index,
      :last_applied,
      :id,
      :state_machine,
      :status,
      :leader_id

    def initialize(id)
      @id = id
      @log = Log.new
      @current_term = 0
      @commit_index = 0
      @last_applied = 0
      @state_machine = StateMachine.new
      @status = Status::Follower
    end

    def append_entries(params)
      return _append_entries_result(false) unless params[:term] >= current_term

      _become_follower_on_new_term(params[:term])

      if params[:prev_log_term] > 0
        previous_log_entry = log[params[:prev_log_index]]
        return _append_entries_result(false) if previous_log_entry.nil?

        if previous_log_entry[:term] != params[:prev_log_term]
          log.truncate_from!(params[:prev_log_index])
          return _append_entries_result(false)
        end
      end

      log.append_entries(current_term, params[:entries])

      if commit_index < params[:leader_commit]
        @commit_index = [params[:leader_commit], log.length].min
        _apply_to_state_machine
      end

      _append_entries_result(true)
    end

    def _apply_to_state_machine
      log.do_on(last_applied, commit_index) do |log_entry|
        state_machine.apply(log_entry[:value])
      end
      @last_applied = commit_index
    end

    def _append_entries_result(success)
      {:term => current_term, :success => success}
    end

    def request_vote(params)
      return _request_vote_result(false) if params[:term] <= current_term

      _become_follower_on_new_term(params[:term])

      return _request_vote_result(false) unless voted_for.nil?

      if log.empty? || (params[:last_log_index] >= log.length &&
          params[:last_log_term] >= log.last[:term])
        @voted_for = params[:candidate_id]
        _request_vote_result(true)
      else
        _request_vote_result(false)
      end
    end

    def _request_vote_result(vote_granted)
      {:term => current_term, :vote_granted => vote_granted}
    end

    def _become_follower_on_new_term(sender_term)
      if sender_term > current_term
        @status = Status::Follower
        @voted_for = nil
        @current_term = sender_term
      end
    end
  end
end
