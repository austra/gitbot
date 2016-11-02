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

#Translate slack username to github username
GIT_USERS = {
  "ryan.fox" => "austra",
  "aaron.swensen" => "aarow75",
  "chris.iriondo" => "Astrofin",
  "ryan.riley" => "block2150",
  "charles" => "cmallela",
  "darren.hicks" => "deevis",
  "jayaramdatti" => "jdatti",
  "lavanya.seerapu" => "lavanyaseerapu",
  "les.buchanan" => "les-buchanan",
  "madan" => "madx80",
  "matt.wingle" => "mwingle",
  "nareshkumarp" => "nareshkumarp",
  "neelima.paluri" => "neelimapaluri",
  "pavanvarma" => "pavanvarma",
  "ramarajukoppada" => "ramarajukoppada",
  "sai.ponduru" => "saiponduru",
  "andy.schuler" => "shoeman22",
  "srinivasmaka" => "srinivasmaka",
  "uday" => "udayburada",
  "venkataraoss" => "venkataraoss",
  "vijay.koppala" => "vijay-koppala",
  "chad.buttars" => "chadbuttars",
  "rajesh.srinivasan" => "rajeshsrinivas",
  "brian-davis" => "brian-davis",
  "arungunturu" => "arunsgunturu",
  "kevinmcevoy" => "kevinmcevoy",
  "aditya54" => "adityabeesa",
  "kamalakar" => "kamal7605",
  # => "varaprasd",
  "mdpack" => "mdpack",
  "wington" => "wingtonbritto",
  "ewell721" => "plato721",
  "subrat" => "subratrout",
  "rick" => "ricas07",
  "prasad.mahanti" => "prasadmahanti31"
}

# Example incoming params from Slack
#
# {
#   "token"=>"DLu95t2bfgd3ADYWQ76POO3f", 
#   "team_id"=>"T07327UAX", 
#   "team_domain"=>"icentris", 
#   "service_id"=>"91712603009", 
#   "channel_id"=>"C2X1UJSAE", 
#   "channel_name"=>"ryantest2", 
#   "timestamp"=>"1478019932.000007", 
#   "user_id"=>"U0AEP0R7V", 
#   "user_name"=>"ryan", 
#   "text"=>"gitbot release", 
#   "trigger_word"=>"gitbot"
# }

post '/git' do
  # Slack text input should be in the form:
  # action repo=xxx base=xxx
  # 
  #return if params[:token] != ENV['SLACK_TOKEN']
  slack_user = params[:user_name].downcase.chomp
  git_user = GIT_USERS[slack_user]
  input = params[:text].gsub(params[:trigger_word],"").strip.split(/ /)
  action = input.shift
  begin
    options = parse_params(input)
  rescue
    options = {}
  end
  repo ||= "pyr"
  repo_url = "iCentris/#{repo}"

  case action
  when 'help'
    message =  "gitbot pulls - Shows your open pull requests in a given repo.  Defaults to pyr, optionally add a repo using repo=pyr-avon\n"
    message += "gitbot reviewed - Shows open and code reviewed pull requests in a given repo and on a given base branch.  Must supply options in the form, base=1.10 repo=pyr\n"
    message += "gitbot release - Generates release notes based on pull requests merged since last tag was taken on supplied base. Must supply options in the form, base=1.10 repo=pyr\n"
    message
  when 'pulls'
    # Users open pull requests in a given repo
    search_results = OCTOKIT.search_issues("author:#{git_user} type:pr state:open repo:#{repo_url}")
    pulls = search_results[:items]
    message = "#{pulls.count} Outstanding Open Pull Requests In #{repo}"
    if pulls.count > 0
      str = pulls.map{ |pr| pr[:url] }.join("\n")
      message += "\n#{str}"
    end
  when 'reviewed'
    # Outstanding open pull requests given base/repo, ie: 1.10-AVON / PYR
    if options.key?(:base) && options.key?(:repo)
      search_results = OCTOKIT.search_issues("type:pr base:#{base} state:open repo:#{repo_url} label:\"Code Reviewed\"")
      pulls = search_results[:items]
      message = "#{pulls.count} #{repo} Outstanding Open and Code Reviewed Pull Requests"
      if pulls.count > 0
        str = pulls.map{ |pr| "#{pr[:title]} #{pr[:url]}" }.join("\n")
        message += "\n#{str}"
      end
    else
      message = "Please supply a base and repo value\nbase=1.10-AVON repo=pyr"
    end
  when 'release'
    # Merged pull requests in a given base/repo since last release
    if options.key?(:base) && options.key?(:repo)
      releases = OCTOKIT.list_releases(repo_url)
      last_release = releases.detect{|r| r.target_commitish == "#{base}"}
      date = last_release.created_at.strftime("%Y-%m-%d")
      search_results = OCTOKIT.search_issues("type:pr base:#{base} state:closed repo:#{repo_url} merged:>#{date}")
      pulls = search_results[:items]
      message = "#{pulls.count} Release Notes Since Last Release (#{r1.name} - #{r1.tag_name} - #{date})"
      if pulls.count > 0
        str = pulls.map{ |pr| "#{pr[:title]} #{pr[:url]}" }.join("\n")
        message += "\n#{str}"
      end
    else
      message = "Please supply a base and repo value\nbase=1.10-AVON repo=pyr"
    end
  end
  puts message
  send_slack message
end

def parse_params(input)
  input.inject(Hash.new{|h,k| h[k]=""}) do |h, s|
    k,v = s.split(/=/)
    h[k.to_sym] << v
    h
  end
end

def send_slack message
  content_type :json
  reply = { username: 'gitbot', icon_emoji: ':alien:', text: message }
  reply.to_json
end