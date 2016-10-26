require 'sinatra'
require 'json'
require 'octokit'
require 'dotenv'
require 'json'
require 'pry'

Dotenv.load

ACCESS_TOKEN = ENV['ACCESS_TOKEN']
OCTOKIT      = Octokit::Client.new(access_token: ACCESS_TOKEN)
USER = OCTOKIT.user
USER.login
OCTOKIT.auto_paginate = true

GIT_USERS = {
"ryan fox" => "austra"
}

post '/git' do
  #return if params[:token] != ENV['SLACK_TOKEN']
  slack_user = params[:user_name].downcase
  puts "#{slack_user}"
  puts params[:user_name].downcase
  git_user = "austra"
  action = params[:text].gsub(params[:trigger_word], '').strip
  repo_url = "iCentris/pyr"

  case action
  when 'pulls'
    puts "#{git_user}"
    search_results = OCTOKIT.search_issues("author:#{git_user} type:pr state:open repo:#{repo_url}")
    pulls = search_results[:items]
    #all_pulls = OCTOKIT.pulls repo_url
    message = "#{pulls.count} Outstanding Pull Requests"
    if pulls.count > 0
      str = pulls.map{ |pr| pr[:url] }.join("\n")
      message += "\n#{str}"
    end
  when 'avon'
    search_results = OCTOKIT.search_issues("type:pr state:open repo:#{repo_url} label:\"Code Reviewed\"")
    pulls = search_results[:items]
    message = "#{pulls.count} Outstanding Avon Code Reviewed Pull Requests"
    if pulls.count > 0
      str = pulls.map{ |pr| "#{pr[:title]} #{pr[:url]}" }.join("\n")
      message += "\n#{str}"
    end
  end
  send_slack message
end

def send_slack message
  content_type :json
  reply = { username: 'gitbot', icon_emoji: ':alien:', text: message }
  reply.to_json
end