require "spec_helper"

describe Raft::Log do
  it "works like an 1 indexed array" do
    log = Raft::Log.new
    log[1] = "a"

    expect(log[1]).to eq("a")
    expect(log.length).to eq(1)

    log << "b"
    expect(log[2]).to eq("b")
    expect(log.length).to eq(2)

    expect(log.last).to eq("b")
  end

  describe "truncate_from!" do
    it "drops elements of the log after the given index" do
      log = Raft::Log.new
      log << "a" << "b" << "c"

      log.truncate_from!(2)

      expect(log.to_a).to eq(["a"])
    end
  end
end
