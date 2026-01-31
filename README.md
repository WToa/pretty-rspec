# Pretty RSpec

A beautiful RSpec formatter with dynamic progress bars and styled terminal output.

## Installation

Add to your Gemfile:

```ruby
# Dependencies (required)
gem "charm-native", github: "esmarkowski/charm-native"
gem "lipgloss", github: "esmarkowski/lipgloss-ruby", branch: "no-path-gemfiles"
gem "bubbles", github: "esmarkowski/bubbles-ruby", branch: "no-path-gemfiles"

gem "pretty_rspec", github: "yourusername/pretty-rspec"
```

Then run:

```bash
bundle install
```

**Note:** The `charm-native` gem requires Go 1.23+ to build the native extensions. If you encounter build errors, run:

```bash
cd $(bundle show charm-native)/go
mkdir -p build/darwin_arm64  # or linux_amd64, etc.
go build -buildmode=c-archive -o build/darwin_arm64/libcharm_native.a .
bundle install
```

## Usage

### Option 1: Command Line

```bash
bundle exec rspec --format PrettyRspec::Formatter
```

### Option 2: Add to `.rspec` file

Create or edit `.rspec` in your project root:

```
--format PrettyRspec::Formatter
```

Then just run:

```bash
bundle exec rspec
```

### Option 3: RSpec Configuration

Add to your `spec/spec_helper.rb`:

```ruby
require "pretty_rspec"

RSpec.configure do |config|
  config.formatter = PrettyRspec::Formatter
end
```

## What It Looks Like

When you run your tests, you'll see:

1. **Progress bar** that updates in real-time
   - Green when all tests pass
   - Red when any test fails

2. **Summary box** showing:
   - Total duration
   - Number of examples
   - Pass/fail/pending breakdown

3. **Failures section** (if any) with:
   - Test description
   - File location
   - Error message

4. **Slowest tests table** showing:
   - Top 3 slowest tests
   - Their locations
   - Execution times

## Dependencies

This gem uses the following libraries for beautiful terminal output:

- [lipgloss-ruby](https://github.com/esmarkowski/lipgloss-ruby/tree/no-path-gemfiles) - Style definitions for terminal layouts
- [bubbles-ruby](https://github.com/esmarkowski/bubbles-ruby/tree/no-path-gemfiles) - TUI components including progress bars

## License

MIT
