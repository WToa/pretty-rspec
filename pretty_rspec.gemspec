# frozen_string_literal: true

require_relative "lib/pretty_rspec/version"

Gem::Specification.new do |spec|
  spec.name = "pretty_rspec"
  spec.version = PrettyRspec::VERSION
  spec.authors = ["William Tio"]
  spec.email = ["wtoa.code@gmail.com"]

  spec.summary = "A beautiful RSpec formatter with progress bars and styled output"
  spec.description = "Pretty RSpec formatter using Lipgloss for styling and Bubbles for progress bars. Features dynamic progress tracking, failure summaries, and slowest test reporting."
  spec.homepage = "https://github.com/WToa/pretty-rspec"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", ">= 3.0"
  spec.add_dependency "rspec-expectations", ">= 3.0"
  spec.add_dependency "lipgloss"
  spec.add_dependency "bubbles"

  spec.add_development_dependency "rspec-mocks", ">= 3.0"
end
