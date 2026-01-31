# frozen_string_literal: true

require "rspec/core"
require "rspec/core/formatters/base_formatter"
require "lipgloss"
require "bubbles"

module PrettyRspec
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    RSpec::Core::Formatters.register self,
      :start,
      :example_started,
      :example_passed,
      :example_failed,
      :example_pending,
      :stop,
      :dump_summary

    def initialize(output)
      super(output)
      @example_count = 0
      @total_count = 0
      @passed_count = 0
      @failed_count = 0
      @pending_count = 0
      @failures = []
      @example_times = []
      @current_example = nil
      @has_failures = false
      setup_styles
    end

    def start(notification)
      @total_count = notification.count
      @progress = Bubbles::Progress.new(width: 50)
      @progress.full_color = "#04B575"  # Green
      @progress.empty_color = "#3C3C3C"
      
      output.puts
      output.puts @header_style.render("Running tests...")
      output.puts
    end

    def example_started(notification)
      @current_example = notification.example
    end

    def example_passed(notification)
      @example_count += 1
      @passed_count += 1
      record_example_time(notification.example)
      update_progress
    end

    def example_failed(notification)
      @example_count += 1
      @failed_count += 1
      @has_failures = true
      @progress.full_color = "#FF6B6B"  # Red when failures occur
      
      record_example_time(notification.example)
      record_failure(notification)
      update_progress
    end

    def example_pending(notification)
      @example_count += 1
      @pending_count += 1
      record_example_time(notification.example)
      update_progress
    end

    def stop(_notification)
      output.puts "\n\n"
    end

    def dump_summary(summary)
      render_summary(summary)
      render_failures if @failures.any?
      render_slowest_tests
      render_final_status(summary)
    end

    private

    def setup_styles
      @header_style = Lipgloss::Style.new
        .bold(true)
        .foreground("#7D56F4")

      @success_style = Lipgloss::Style.new
        .bold(true)
        .foreground("#04B575")

      @failure_style = Lipgloss::Style.new
        .bold(true)
        .foreground("#FF6B6B")

      @pending_style = Lipgloss::Style.new
        .bold(true)
        .foreground("#FFCC00")

      @muted_style = Lipgloss::Style.new
        .foreground("#626262")

      @box_style = Lipgloss::Style.new
        .border(:rounded)
        .border_foreground("#874BFD")
        .padding(1, 2)

      @failure_box_style = Lipgloss::Style.new
        .border(:rounded)
        .border_foreground("#FF6B6B")
        .padding(1, 2)
        .margin_top(1)

      @table_header_style = Lipgloss::Style.new
        .bold(true)
        .foreground("#FAFAFA")
        .background("#5A56E0")
        .padding(0, 1)

      @table_cell_style = Lipgloss::Style.new
        .padding(0, 1)
    end

    def update_progress
      percent = @example_count > 0 ? @example_count.to_f / @example_count : 0
      
      status_color = @has_failures ? @failure_style : @success_style
      
      progress_line = [
        @progress.view_as(percent),
        " ",
        status_color.render("#{@passed_count}/#{@example_count}"),
        " ",
        @muted_style.render("("),
        @success_style.render("#{@passed_count} passed"),
        @muted_style.render(", "),
        @failed_count > 0 ? @failure_style.render("#{@failed_count} failed") : @muted_style.render("0 failed"),
        @muted_style.render(", "),
        @pending_count > 0 ? @pending_style.render("#{@pending_count} pending") : @muted_style.render("0 pending"),
        @muted_style.render(")")
      ].join

      # Clear line and reprint progress
      output.print "\r\e[K#{progress_line}"
    end

    def record_example_time(example)
      @example_times << {
        description: example.full_description,
        location: format_location(example.location),
        location_full: location_full_from(example.location),
        time: example.execution_result.run_time
      }
    end

    def record_failure(notification)
      example = notification.example
      exception = notification.exception
      
      @failures << {
        description: example.full_description,
        location: format_location(example.location),
        location_full: location_full_from(example.location),
        message: exception.message,
        backtrace: format_backtrace(exception.backtrace)
      }
    end

    def format_location(location)
      location.to_s.sub(/\A\.\//, "")
    end

    def format_backtrace(backtrace)
      return "" unless backtrace
      backtrace.first(5).join("\n")
    end

    def render_summary(summary)
      duration = format_duration(summary.duration)
      
      summary_text = [
        @header_style.render("Test Summary"),
        "",
        "Duration: #{@muted_style.render(duration)}",
        "Examples: #{@example_count}",
        "",
        build_results_line
      ].join("\n")

      output.puts @box_style.render(summary_text)
    end

    def build_results_line
      parts = []
      parts << @success_style.render("#{@passed_count} passed") if @passed_count > 0
      parts << @failure_style.render("#{@failed_count} failed") if @failed_count > 0
      parts << @pending_style.render("#{@pending_count} pending") if @pending_count > 0
      parts.join("  ")
    end

    def render_failures
      output.puts
      output.puts @failure_style.render("Failures")
      
      @failures.each_with_index do |failure, index|
        failure_content = [
          @failure_style.render("#{index + 1}) #{failure[:description]}"),
          "",
          @muted_style.render("Location: #{failure[:location]}"),
          file_link(failure[:location_full]),
          "",
          "Message:",
          failure[:message].to_s.lines.first(10).join,
        ].join("\n")

        output.puts @failure_box_style.render(failure_content)
      end
    end

    def render_slowest_tests
      output.puts
      output.puts @header_style.render("Top 3 Slowest Tests")
      output.puts

      slowest = @example_times.sort_by { |e| -e[:time] }.first(3)
      
      return output.puts @muted_style.render("  No tests recorded.") if slowest.empty?

      table = Lipgloss::Table.new
        .headers(["#", "Test", "Location", "Duration"])
        .rows(
          slowest.each_with_index.map do |example, index|
            [
              (index + 1).to_s,
              truncate(example[:description], 50),
              file_link(example[:location_full], truncate(example[:location], 30)),
              format_duration(example[:time])
            ]
          end
        )
        .border(:rounded)
        .style_func(rows: slowest.size, columns: 4) do |row, _col|
          if row == Lipgloss::Table::HEADER_ROW
            @table_header_style
          else
            @table_cell_style
          end
        end

      output.puts table.render
    end

    def location_full_from(location)
      parts = location.to_s.split(":")
      line = parts.pop
      file = parts.join(":")
      "#{File.expand_path(file)}:#{line}"
    end

    def file_link(full_path_with_line, display_text = nil)
      display = display_text || full_path_with_line
      "\e]8;;file://#{full_path_with_line}\a#{display}\e]8;;\a"
    end

    def render_final_status(summary)
      output.puts

      if summary.failure_count > 0
        status_box = Lipgloss::Style.new
          .bold(true)
          .foreground("#FFFFFF")
          .background("#FF6B6B")
          .padding(0, 2)
        output.puts status_box.render(" FAILED ")
      elsif summary.pending_count > 0
        status_box = Lipgloss::Style.new
          .bold(true)
          .foreground("#000000")
          .background("#FFCC00")
          .padding(0, 2)
        output.puts status_box.render(" PENDING ")
      else
        status_box = Lipgloss::Style.new
          .bold(true)
          .foreground("#FFFFFF")
          .background("#04B575")
          .padding(0, 2)
        output.puts status_box.render(" PASSED ")
      end

      output.puts
    end

    def format_duration(seconds)
      if seconds < 0.001
        "#{(seconds * 1_000_000).round(2)}µs"
      elsif seconds < 1
        "#{(seconds * 1000).round(2)}ms"
      elsif seconds < 60
        "#{seconds.round(2)}s"
      else
        minutes = (seconds / 60).floor
        secs = (seconds % 60).round(2)
        "#{minutes}m #{secs}s"
      end
    end

    def truncate(str, max_length)
      return str if str.length <= max_length
      "#{str[0, max_length - 3]}..."
    end
  end
end
