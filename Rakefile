# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

task default: :push

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :push do
  system 'git add .'
  system "git commit -m 'Update #{Time.now}.'"
  system 'git pull'
  system 'git push origin master'
end
