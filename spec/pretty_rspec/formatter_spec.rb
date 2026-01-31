# frozen_string_literal: true

require "spec_helper"

RSpec.describe PrettyRspec::Formatter do
  let(:output) { StringIO.new }
  let(:formatter) { described_class.new(output) }

  describe "#initialize" do
    it "initializes with zero counts" do
      expect(formatter.instance_variable_get(:@example_count)).to eq(0)
      expect(formatter.instance_variable_get(:@passed_count)).to eq(0)
      expect(formatter.instance_variable_get(:@failed_count)).to eq(0)
      expect(formatter.instance_variable_get(:@pending_count)).to eq(0)
    end

    it "initializes with empty failures array" do
      expect(formatter.instance_variable_get(:@failures)).to eq([])
    end

    it "initializes with empty example_times array" do
      expect(formatter.instance_variable_get(:@example_times)).to eq([])
    end

    it "initializes has_failures as false" do
      expect(formatter.instance_variable_get(:@has_failures)).to be false
    end

    it "sets up Lipgloss styles" do
      expect(formatter.instance_variable_get(:@header_style)).to be_a(Lipgloss::Style)
      expect(formatter.instance_variable_get(:@success_style)).to be_a(Lipgloss::Style)
      expect(formatter.instance_variable_get(:@failure_style)).to be_a(Lipgloss::Style)
      expect(formatter.instance_variable_get(:@pending_style)).to be_a(Lipgloss::Style)
      expect(formatter.instance_variable_get(:@box_style)).to be_a(Lipgloss::Style)
    end
  end

  describe "#start" do
    it "sets the total count from notification" do
      notification = RSpec::Core::Notifications::StartNotification.new(10)
      formatter.start(notification)
      expect(formatter.instance_variable_get(:@total_count)).to eq(10)
    end

    it "creates a Bubbles progress bar" do
      notification = RSpec::Core::Notifications::StartNotification.new(5)
      formatter.start(notification)
      expect(formatter.instance_variable_get(:@progress)).to be_a(Bubbles::Progress)
    end

    it "configures progress bar with green color" do
      notification = RSpec::Core::Notifications::StartNotification.new(5)
      formatter.start(notification)
      progress = formatter.instance_variable_get(:@progress)
      expect(progress.full_color).to eq("#04B575")
    end

    it "outputs the header message" do
      notification = RSpec::Core::Notifications::StartNotification.new(10)
      formatter.start(notification)
      expect(output.string).to include("Running tests")
    end
  end

  describe "example lifecycle" do
    # Create a minimal example group and example for testing
    let(:example_group) do
      RSpec.describe("Test Group") {}
    end

    before do
      formatter.start(RSpec::Core::Notifications::StartNotification.new(5))
    end

    describe "#example_passed" do
      it "increments example_count and passed_count" do
        # Create a real example
        example = example_group.example("passes") { }
        example.execution_result.status = :passed
        example.execution_result.run_time = 0.05

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)

        formatter.example_passed(notification)

        expect(formatter.instance_variable_get(:@example_count)).to eq(1)
        expect(formatter.instance_variable_get(:@passed_count)).to eq(1)
      end

      it "records example timing data" do
        example = example_group.example("test timing") { }
        example.execution_result.status = :passed
        example.execution_result.run_time = 0.123

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_passed(notification)

        times = formatter.instance_variable_get(:@example_times)
        expect(times.length).to eq(1)
        expect(times.first[:time]).to eq(0.123)
        expect(times.first[:description]).to include("test timing")
      end

      it "updates progress output" do
        example = example_group.example("outputs progress") { }
        example.execution_result.status = :passed
        example.execution_result.run_time = 0.01

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_passed(notification)

        expect(output.string).to include("passed")
      end
    end

    describe "#example_failed" do
      it "increments failed_count and sets has_failures flag" do
        example = example_group.example("fails") { }
        example.execution_result.status = :failed
        example.execution_result.run_time = 0.05
        example.execution_result.exception = StandardError.new("Expected failure")

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_failed(notification)

        expect(formatter.instance_variable_get(:@failed_count)).to eq(1)
        expect(formatter.instance_variable_get(:@has_failures)).to be true
      end

      it "records failure details including message" do
        example = example_group.example("fails with message") { }
        example.execution_result.status = :failed
        example.execution_result.run_time = 0.05
        example.execution_result.exception = StandardError.new("Expected 1 to equal 2")

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_failed(notification)

        failures = formatter.instance_variable_get(:@failures)
        expect(failures.length).to eq(1)
        expect(failures.first[:message]).to eq("Expected 1 to equal 2")
      end

      it "changes progress bar color to red" do
        example = example_group.example("fails") { }
        example.execution_result.status = :failed
        example.execution_result.run_time = 0.01
        example.execution_result.exception = StandardError.new("error")

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_failed(notification)

        progress = formatter.instance_variable_get(:@progress)
        expect(progress.full_color).to eq("#FF6B6B")
      end
    end

    describe "#example_pending" do
      it "increments pending_count" do
        example = example_group.example("pending") { }
        example.execution_result.status = :pending
        example.execution_result.run_time = 0.001

        notification = RSpec::Core::Notifications::ExampleNotification.for(example)
        formatter.example_pending(notification)

        expect(formatter.instance_variable_get(:@pending_count)).to eq(1)
        expect(formatter.instance_variable_get(:@example_count)).to eq(1)
      end
    end
  end

  describe "duration formatting" do
    it "formats sub-millisecond as microseconds" do
      result = formatter.send(:format_duration, 0.0005)
      expect(result).to match(/\d+(\.\d+)?µs/)
    end

    it "formats sub-second as milliseconds" do
      result = formatter.send(:format_duration, 0.5)
      expect(result).to match(/\d+(\.\d+)?ms/)
    end

    it "formats seconds" do
      result = formatter.send(:format_duration, 5.5)
      expect(result).to eq("5.5s")
    end

    it "formats durations over a minute" do
      result = formatter.send(:format_duration, 125.5)
      expect(result).to eq("2m 5.5s")
    end
  end

  describe "text truncation" do
    it "returns short strings unchanged" do
      result = formatter.send(:truncate, "short", 10)
      expect(result).to eq("short")
    end

    it "truncates long strings and adds ellipsis" do
      result = formatter.send(:truncate, "this is a very long string", 15)
      expect(result).to eq("this is a ve...")
      expect(result.length).to eq(15)
    end

    it "handles exact length strings" do
      result = formatter.send(:truncate, "exactly10!", 10)
      expect(result).to eq("exactly10!")
    end
  end

  describe "location formatting" do
    it "removes leading ./ from paths" do
      result = formatter.send(:format_location, "./spec/test_spec.rb:10")
      expect(result).to eq("spec/test_spec.rb:10")
    end

    it "leaves paths without ./ unchanged" do
      result = formatter.send(:format_location, "spec/test_spec.rb:10")
      expect(result).to eq("spec/test_spec.rb:10")
    end
  end

  describe "backtrace formatting" do
    it "returns empty string for nil backtrace" do
      result = formatter.send(:format_backtrace, nil)
      expect(result).to eq("")
    end

    it "limits backtrace to first 5 lines" do
      backtrace = (1..10).map { |i| "line #{i}" }
      result = formatter.send(:format_backtrace, backtrace)
      lines = result.split("\n")
      expect(lines.length).to eq(5)
      expect(lines.first).to eq("line 1")
      expect(lines.last).to eq("line 5")
    end
  end

  describe "#dump_summary" do
    let(:example_group) { RSpec.describe("Summary Test") {} }

    before do
      formatter.start(RSpec::Core::Notifications::StartNotification.new(3))
    end

    # Helper to create a summary notification
    # Members: duration, examples, failed_examples, pending_examples, load_time, errors_outside_of_examples_count
    def create_summary(duration:, failed_examples: [], pending_examples: [], load_time: 0.1)
      RSpec::Core::Notifications::SummaryNotification.new(
        duration, [], failed_examples, pending_examples, load_time, 0
      )
    end

    it "renders a summary box with Test Summary header" do
      summary = create_summary(duration: 1.5)
      formatter.dump_summary(summary)
      expect(output.string).to include("Test Summary")
    end

    it "renders the slowest tests section header" do
      summary = create_summary(duration: 1.5)
      formatter.dump_summary(summary)
      expect(output.string).to include("Slowest Tests")
    end

    it "renders PASSED when all tests pass" do
      formatter.instance_variable_set(:@passed_count, 3)
      summary = create_summary(duration: 1.5)
      formatter.dump_summary(summary)
      expect(output.string).to include("PASSED")
    end

    it "renders FAILED when there are failures" do
      formatter.instance_variable_set(:@failed_count, 1)
      # Create a fake failed example
      failed_example = example_group.example("failed") { }
      summary = create_summary(duration: 1.5, failed_examples: [failed_example])
      formatter.dump_summary(summary)
      expect(output.string).to include("FAILED")
    end

    it "renders PENDING when only pending tests exist" do
      formatter.instance_variable_set(:@pending_count, 1)
      pending_example = example_group.example("pending") { }
      summary = create_summary(duration: 1.5, pending_examples: [pending_example])
      formatter.dump_summary(summary)
      expect(output.string).to include("PENDING")
    end

    it "renders slowest tests as a table when tests are recorded" do
      # Record some example times
      formatter.instance_variable_set(:@example_times, [
        { description: "slow test 1", location: "spec/a_spec.rb:1", time: 0.5 },
        { description: "slow test 2", location: "spec/b_spec.rb:2", time: 0.3 },
        { description: "fast test", location: "spec/c_spec.rb:3", time: 0.01 }
      ])

      summary = create_summary(duration: 1.0)
      formatter.dump_summary(summary)

      # Should show slowest first
      expect(output.string).to include("slow test 1")
      expect(output.string).to include("slow test 2")
    end
  end

  describe "results line building" do
    before do
      formatter.start(RSpec::Core::Notifications::StartNotification.new(10))
    end

    it "includes passed count" do
      formatter.instance_variable_set(:@passed_count, 5)
      result = formatter.send(:build_results_line)
      expect(result).to include("5 passed")
    end

    it "includes failed count" do
      formatter.instance_variable_set(:@failed_count, 2)
      result = formatter.send(:build_results_line)
      expect(result).to include("2 failed")
    end

    it "includes pending count" do
      formatter.instance_variable_set(:@pending_count, 1)
      result = formatter.send(:build_results_line)
      expect(result).to include("1 pending")
    end

    it "combines multiple result types" do
      formatter.instance_variable_set(:@passed_count, 5)
      formatter.instance_variable_set(:@failed_count, 2)
      formatter.instance_variable_set(:@pending_count, 1)
      result = formatter.send(:build_results_line)

      expect(result).to include("5 passed")
      expect(result).to include("2 failed")
      expect(result).to include("1 pending")
    end
  end
end
