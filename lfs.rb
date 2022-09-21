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

FILEPATH = "reports/#{ARGV[0]}-lfs.csv"
BATCH_SIZE= ENV["BATCH_SIZE"].nil? ? 5: ENV["BATCH_SIZE"].to_i

def git_lfs(*args)
  Dir.chdir(*args) do
    git_lfs_path = Cliver.detect! 'git'
    Open3.capture2e(git_lfs_path, "lfs", "ls-files","-s")
  end
end

def git_lfs_size(*args)
  lfs_list, status = git_lfs(*args)

  lfs_lines = lfs_list.split("\n")
  sum = lfs_lines.map do |line|
    matched = line.match(/(\([0-9]+\.*[0-9]* [A-Z]+\)$)/)[0].gsub(/[()]/, "").split(" ")[0].to_f
    matched.nil? ? 0 : matched
  end.sum

  sum
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

client = Octokit::Client.new access_token: ENV["GITHUB_TOKEN"]
client.auto_paginate = true

repos = client.organization_repositories(ARGV[0].strip, type: 'sources')
puts "Found #{repos.count} repos. Counting..."

status = $?

reports = []
File.open(FILEPATH, "w") do |f|
  repos.each_slice(BATCH_SIZE) do |repos|
    puts "Cloning #{BATCH_SIZE} repos..."

      repos.each do |repo|
        puts "Counting #{repo.name}..."

        destination = File.expand_path repo.name, tmp_dir

        clone_url = repo.clone_url
        clone_url = clone_url.sub "//", "//#{ENV["GITHUB_TOKEN"]}:x-oauth-basic@" if ENV["GITHUB_TOKEN"]
        output, status = Open3.capture2e "git", "clone", "--depth", "1", "--quiet", clone_url, destination

        next unless status.exitstatus == 0

        output = git_lfs_size destination

        puts "LFS files found with a total size of #{output} MB"

        if output == 0
          puts "No LFS files found in #{repo.name}"
        else
          f.write "#{repo.name}, #{output}\n"
        end

        puts "Removing #{repo.name} from local disk..."
        FileUtils.remove_dir("#{tmp_dir}/#{repo.name}")
      end
  end
end
puts "Done!"

puts
puts "------------------------------------------"
puts "Results written to #{FILEPATH}"
puts "------------------------------------------"

exit status.exitstatus
