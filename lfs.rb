require 'octokit'
require 'open3'
require 'cliver'
require 'dotenv'
require 'csv'
require 'fileutils'

if ARGV.count != 1
  puts "Usage: script/count [ORG NAME]"
  exit 1
end

Dotenv.load

def git_lfs(*args)
  Dir.chdir(*args) do
    git_lfs_path = Cliver.detect! 'git'
    Open3.capture2e(git_lfs_path, "lfs", "ls-files")
  end
end

tmp_dir = File.expand_path "./tmp", File.dirname(__FILE__)
FileUtils.rm_rf tmp_dir
FileUtils.mkdir_p tmp_dir

# Enabling support for GitHub Enterprise
unless ENV["GITHUB_ENTERPRISE_URL"].nil?
  Octokit.configure do |c|
    c.api_endpoint = ENV["GITHUB_ENTERPRISE_URL"]
  end
end

if ENV["BATCH_SIZE"].nil?
  BATCH_SIZE = 5
else
  BATCH_SIZE = ENV["BATCH_SIZE"].to_i
end

client = Octokit::Client.new access_token: ENV["GITHUB_TOKEN"]
client.auto_paginate = true

repos = client.organization_repositories(ARGV[0].strip, type: 'sources')
puts "Found #{repos.count} repos. Counting..."

status = $?

reports = []
repos.each_slice(BATCH_SIZE) do |repos|
  puts "Cloning #{BATCH_SIZE} repos..."

  repos.each do |repo|
    puts "Counting #{repo.name}..."

    destination = File.expand_path repo.name, tmp_dir
    report_file = File.expand_path "#{repo.name}.txt", tmp_dir

    clone_url = repo.clone_url
    clone_url = clone_url.sub "//", "//#{ENV["GITHUB_TOKEN"]}:x-oauth-basic@" if ENV["GITHUB_TOKEN"]
    output, status = Open3.capture2e "git", "clone", "--depth", "1", "--quiet", clone_url, destination
    puts status.class
    next unless status.exitstatus == 0

    output,status = git_lfs destination
    if output.length == 0
      puts "No LFS files found in #{repo.name}"
    else
      File.write report_file, output
    end

    reports.push(report_file) if File.exists?(report_file) && status.exitstatus == 0
    puts "Removing #{repo.name} from local disk..."
    FileUtils.remove_dir("#{tmp_dir}/#{repo.name}")
  end
end

puts "Done. Summing..."


FILEPATH = "reports/#{ARGV[0]}-lfs.csv"

puts
puts "---------------------------------------"
puts "Results written to #{FILEPATH}"
puts "---------------------------------------"

exit status.exitstatus
