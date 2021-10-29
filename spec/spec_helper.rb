require 'spec_helper'

require 'knapsack'
require 'logger'

Knapsack::Adapters::RSpecAdapter.bind

LOGGER = Logger.new("log/test-#{ENV.fetch('BUILDKITE_PARALLEL_JOB', 0)}.log")
LOGGER.formatter = -> (_severity, _datetime, _progname, msg) do
  "#{msg.to_json}\n"
end
KEYS = %i[foo bar baz qux].freeze

LOGGER.debug(env: ENV.keys)