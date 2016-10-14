require 'sinatra'
require 'json'
require 'octokit'
require 'dotenv'
require 'json'
require 'pry'

Dotenv.load



post '/git' do
git_users = {
"ryan fox" => "austra"
}
access_token = ENV['ACCESS_TOKEN']
octokit      = Octokit::Client.new(access_token: ACCESS_TOKEN)
user = OCTOKIT.user
user.login
octokit.auto_paginate = true
  #return if params[:token] != ENV['SLACK_TOKEN']
  slack_user = params[:user_name].downcase
  puts "#{slack_user}"
  puts params[:user_name].downcase
  git_user = git_users[slack_user]
  action = params[:text].gsub(params[:trigger_word], '').strip
  repo_url = "iCentris/pyr"

  case action
  when 'pulls'
    puts "#{git_user}"
    search_results = octokit.search_issues("author:#{git_user} type:pr state:open repo:#{repo_url}")
    pulls = search_results[:items]
    #all_pulls = OCTOKIT.pulls repo_url
    message = "#{pulls.count} Outstanding Pull Requests"
    if pulls.count > 0
      str = pulls.map{ |pr| pr[:url] }.join("\n")
      message += "\n#{str}"
    end
    send_slack message
  end
end

def send_slack message
  content_type :json
  reply = { username: 'gitbot', icon_emoji: ':alien:', text: message }
  reply.to_json
end