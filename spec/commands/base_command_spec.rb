require "rails_helper"

RSpec.describe Commands::BaseCommand do
  let(:top_level_worker) { double(:top_level_worker, some_method: nil) }
  let(:nested_worker) { double(:nested_worker, some_method: nil) }

  class TopLevelCommand < Commands::BaseCommand
    def call
      after_transaction_commit do
        payload[:top_level_worker].some_method
      end

      NestedCommand.call(payload, callbacks: callbacks, nested: true)
    end
  end

  class NestedCommand < Commands::BaseCommand
    def call
      after_transaction_commit do
        payload[:nested_worker].some_method
      end
    end
  end

  describe "callbacks for nested commands" do
    it "executes callbacks at the top level of the command tree" do
      expect(TopLevelCommand).to receive(:execute_callbacks)
      expect(NestedCommand).not_to receive(:execute_callbacks)

      TopLevelCommand.call({})
    end

    it "executes all callbacks from every level of the command tree" do
      expect(top_level_worker).to receive(:some_method)
      expect(nested_worker).to receive(:some_method)

      payload = {
        top_level_worker: top_level_worker,
        nested_worker: nested_worker,
      }

      TopLevelCommand.call(payload)
    end
  end
end
