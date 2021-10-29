#!/usr/bin/env ruby

require 'English'
require 'json'
require 'net/http'
require 'uri'

class LogAggregator
  API          = 'https://graphql.buildkite.com/v1'
  BUILD        = ENV.fetch('BUILD') { ENV.fetch('BUILDKITE_BUILD_NUMBER') }
  HEADERS      = { 'Authorization' => "Bearer #{ENV['BUILDKITE_API_TOKEN']}" }
  MAX_PER_PAGE = 500
  ORGANIZATION = ENV.fetch('BUILDKITE_ORGANIZATION_SLUG', 'hint')
  PIPELINE     = ENV.fetch('BUILDKITE_PIPELINE_SLUG', 'buildkite-playground')

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
    puts GRAPHQL
    json = request(API, data: { query: GRAPHQL }, headers: HEADERS, method: "POST")
    jobs = json['data']['build']['jobs']['edges'].map { |edge| edge['node'] }
    @artifacts = jobs.flat_map { |job| job['artifacts']['edges'] }.map { |edge| edge['node'] }
  end

  def aggregate_logs
    aggregate_report = @artifacts.each_with_object({}) do |artifact, report|
      #next unless artifact['path'] == REPORT_DIFF
      puts "~~~ Downloading artifact #{artifact['uuid']}"
      report.update request(artifact['downloadURL'])
    end

    puts "--- Writing new #{REPORT} for current tests"
    agregate_report.select! { |test, _time| File.exist?(test) }
    json = JSON.pretty_generate(aggregate_report.sort.to_h)
    File.write('jason_report.json', json)
  end

  def request(url, data: nil, headers: {}, method: 'GET')
    uri = URI(url)
    data &&= JSON.generate(data)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.send_request(method, uri.request_uri, data, headers)
    puts response.code
    puts response.body
    response.body.empty? ? {} : JSON.parse(response.body)
  end
end

LogAggregator.new.run if $PROGRAM_NAME == __FILE__