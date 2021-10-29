#!/usr/bin/env ruby

require 'base64'
require 'English'
require 'json'
require 'net/http'
require 'uri'

class LogAggregator
  API          = 'https://graphql.buildkite.com/v1'
  BUILD        = ENV.fetch('BUILD') { ENV.fetch('BUILDKITE_BUILD_NUMBER') }
  FOO          = Base64.decode64(ENV.fetch('FOO'))
  HEADERS      = { 'Authorization' => "Bearer #{FOO}" }
  MAX_PER_PAGE = 500
  ORGANIZATION = ENV.fetch('BUILDKITE_ORGANIZATION_SLUG', 'hint')
  PIPELINE     = ENV.fetch('BUILDKITE_PIPELINE_SLUG', 'buildkite-playground')
  REPORTS      = %w[testA testB]

  GRAPHQL = <<~GRAPHQL
    query {
      build(slug: "#{ORGANIZATION}/#{PIPELINE}/#{BUILD}") {
        jobs(first: #{MAX_PER_PAGE}, step: { key: "ruby" }) {
          edges {
            node {
              ... on JobTypeCommand {
                artifacts(first: #{MAX_PER_PAGE}) {
                  edges {
                    node {
                      downloadURL
                      path
                      uuid
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  def run
    find_knapsack_artifacts
    aggregate_logs
  end

  private

  def find_knapsack_artifacts
    puts "--- Finding knapsack artifacts in build #{BUILD}"

    @artifacts = pipeline_artifacts
  end

  def pipeline_artifacts
    jobs.flat_map do |job|
      job.dig('artifacts', 'edges').map do |edge|
        edge.fetch('node')
      end
    end
  end

  def jobs
    query_json.dig('data', 'build', 'jobs', 'edges').map do |edge|
      edge.fetch('node')
    end
  end

  def query_json
    JSON.parse(query_result)
  end

  def query_result
    request(API, data: { query: GRAPHQL }, headers: HEADERS, method: "POST")
  end

  def aggregate_logs
    REPORTS.each do |prefix|
      report = aggregate_report(prefix)
      next if report.empty?

      puts "--- Writing new report for #{prefix}"
      File.write("log/#{prefix}.json", report.to_json)
    end
  end

  def aggregate_report(prefix)
    @artifacts.each_with_object([]) do |artifact, report|
      next unless artifact['path'].start_with?("log/#{prefix}-")

      artifact_content(artifact).each_line do |line|
        report << JSON.parse(line)
      rescue JSON::ParserError => _e
        puts "unable to parse: '#{line}'"
      end
    end
  end

  def artifact_content(artifact)
    puts "~~~ Downloading artifact #{artifact['uuid']}, #{artifact['path']}"
    request(artifact['downloadURL'])
  end

  def request(url, data: nil, headers: {}, method: 'GET')
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.send_request(method, uri.request_uri, data&.to_json, headers)
    response.body
  end
end

LogAggregator.new.run if $PROGRAM_NAME == __FILE__
