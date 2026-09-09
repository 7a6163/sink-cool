# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

desc "Run mutation coverage (config in .mutant.yml)"
task :mutant do
  sh "bundle", "exec", "mutant", "run", *Array(ENV["MUTANT_ARGS"]&.split)
end

task default: :test
