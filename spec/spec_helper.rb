require 'spec_helper'

require 'knapsack'
require 'logger'

Knapsack::Adapters::RSpecAdapter.bind

LOGGER1 = Logger.new("log/test1-#{ENV.fetch('BUILDKITE_PARALLEL_JOB', 0)}.log")
LOGGER2 = Logger.new("log/test2-#{ENV.fetch('BUILDKITE_PARALLEL_JOB', 0)}.log")
LOGGER1.formatter = -> (_severity, _datetime, _progname, msg) do
  "#{msg.to_json}\n"
end
LOGGER2.formatter = LOGGER1.formatter

KEYS = %i[foo bar baz qux].freeze

LOGGER1.debug(env: ENV.to_h)