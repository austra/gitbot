require 'sinatra'
require 'json'
require 'octokit'
require 'dotenv'
require 'json'
require 'pry'
require 'active_support/all'

# require 'jira-ruby'

# JIRA_OPTIONS = {
#   :username     => ENV['JIRA_USERNAME'],
#   :password     => ENV['JIRA_PASSWORD'],
#   :site         => 'https://jira2.icentris.com/',
#   :context_path => '',
#   :auth_type    => :basic
# }

# JIRA_CLIENT = JIRA::Client.new(JIRA_OPTIONS)

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
  if options.key?(:repo)
    repo = options[:repo]
  end
  repo ||= "pyr"
  repo_url = "iCentris/#{repo}"

  case action
  when 'help'
    message =  "pulls repo=pyr-idlife - Shows your open pull requests in a given repo.  Defaults to pyr, optionally add a repo using repo=pyr-avon\n"
    message += "reviewed base=1.10-VTUP repo=pyr - Shows open and code reviewed pull requests in a given repo and on a given base branch.  Must supply options in the form, base=1.10 repo=pyr\n"
    message += "release base=1.10-AVON repo=pyr - Generates release notes based on pull requests merged since last tag was taken on supplied base. Must supply options in the form, base=1.10-AVON repo=pyr\n"
    message += "Repo defaults to pyr if not specified."
  when 'pulls'
    # Users open pull requests in a given repo
    search_results = OCTOKIT.search_issues("author:#{git_user} type:pr state:open repo:#{repo_url}")
    pulls = search_results.items
    message = "Repo: #{repo} - #{pulls.count} Outstanding Open Pull Requests"
    if pulls.count > 0
      str = pulls.map{ |pr| pr.html_url }.join("\n")
      message += "\n#{str}"
    end
  when 'reviewed'
    # Outstanding open pull requests given base/repo, ie: 1.10-AVON / PYR
    # TODO: date of approval / days waiting to be merged
    if options.key?(:base)
      search_results = OCTOKIT.search_issues("type:pr base:#{options[:base]} state:open repo:#{repo_url} label:\"Code Reviewed\"")
      pulls = search_results.items
      message = "Base: #{options[:base]} - Repo: #{repo} - #{pulls.count} Outstanding Open and Code Reviewed Pull Requests"
      if pulls.count > 0
        str = pulls.map{ |pr| "#{pr.title} #{pr.html_url} - #{pr.updated_at}" }.join("\n")
        message += "\n#{str}"
      end
    else
      message = "Please supply a base and repo value\nbase=1.10-AVON repo=pyr"
    end
  when 'release'
    # Merged pull requests in a given base/repo since last release
    #TODO: Group by bugfix/new feature by using Jira api
    if options.key?(:base)
      releases = OCTOKIT.list_releases(repo_url)
      last_release = releases.detect{|r| r.target_commitish == "#{options[:base]}"}
      date = last_release.created_at.strftime("%Y-%m-%d")
      search_results = OCTOKIT.search_issues("type:pr base:#{options[:base]} state:closed repo:#{repo_url} merged:>#{date}")
      pulls = search_results.items
      message = "Base: #{options[:base]} - Repo: #{repo} - #{pulls.count} Release Notes Since Last Release (#{last_release.name} - #{last_release.tag_name} - #{date})"
      if pulls.count > 0
        title = pr.title.split(" ").first
        str = pulls.map{ |pr| "#{pr.title} #{pr.html_url}" }.join("\n")
        message += "\n#{str}"
      end
    else
      message = "Please supply a base and repo value\nbase=1.10-AVON repo=pyr"
    end
  when 'master'
    message = master_pulls
  end
  puts message
  return send_slack message
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

def master_pulls
  pyr_master_pulls     = OCTOKIT.search_issues("type:pr repo:iCentris/pyr base:master", {per_page: 100, pages: 1}).items
  master_titles        = pyr_master_pulls.map(&:title)

  # pyr_1_10_AVON_pulls  = OCTOKIT.search_issues("type:pr repo:iCentris/pyr base:1.10-AVON", {per_page: 100, pages: 1}).items
  pyr_1_11_MNT_pulls   = OCTOKIT.search_issues("type:pr repo:iCentris/pyr base:1.11-MNT", {per_page: 100, pages: 1}).items
  # pyr_2_0_VTUP_pulls   = OCTOKIT.search_issues("type:pr repo:iCentris/pyr base:2.0-VTUP", {per_page: 100, pages: 1}).items
  # pyr_2_1_IDLV_pulls   = OCTOKIT.search_issues("type:pr repo:iCentris/pyr base:2.1-idlife", {per_page: 100, pages: 1}).items

  # pyr_avon_pulls       = OCTOKIT.search_issues("type:pr repo:iCentris/pyr-avon base:master", {per_page: 100, pages: 1}).items
  # pyr_avon_titles      = pyr_master_pulls.map(&:title)

  # pyr_avon_1_10_pulls  = OCTOKIT.search_issues("type:pr repo:iCentris/pyr-avon base:1.10-AVON", {per_page: 100, pages: 1}).items

  # pyr_monat_pulls      = OCTOKIT.search_issues("type:pr repo:iCentris/pyr-monat base:master", {per_page: 100, pages: 1}).items
  # pyr_monat_titles     = pyr_master_pulls.map(&:title)

  # pyr_monat_1_11_pulls = OCTOKIT.search_issues("type:pr repo:iCentris/pyr-monat base:1.11-MNT", {per_page: 100, pages: 1}).items

  pyr_missing_pulls = []
  
  #[pyr_1_11_MNT_pulls, pyr_1_10_AVON_pulls, pyr_2_0_VTUP_pulls , pyr_2_1_IDLV_pulls].each do |pulls|
  [pyr_1_11_MNT_pulls].each do |pulls|
    pyr_missing_pulls << pulls.reject{|pr| pr[:created_at].to_i < 1.months.ago.to_i}.reject{|pr| pr[:title].in?(master_titles)}
  end

  pyr_missing_pulls.flatten!

  # pyr_avon_missing_pulls = pyr_avon_1_10_pulls.reject{|pr| pr[:created_at].to_i < 1.months.ago.to_i}.reject{|pr| pr[:title].in?(pyr_avon_titles)}
  # pyr_avon_missing_pulls.flatten!

  # pyr_monat_missing_pulls = pyr_monat_1_11_pulls.reject{|pr| pr[:created_at].to_i < 1.months.ago.to_i}.reject{|pr| pr[:title].in?(pyr_monat_titles)}
  # pyr_monat_missing_pulls.flatten!

  formatted_pulls = []
  
  #[pyr_missing_pulls, pyr_avon_missing_pulls, pyr_monat_missing_pulls].each do |pulls|
  [pyr_missing_pulls].each do |pulls|
    formatted_pulls << pulls.map{|pr| {title: pr[:title], repo: pr[:repository_url], url: pr[:url], author: "@#{pr[:user][:login]}"}}
  end

  formatted_pulls.flatten!(1)
  grouped = formatted_pulls.group_by{|pr| pr[:author]}

  msg = ""
  grouped.each do |author, pulls|
    msg << "#########################\n"
    msg << "#{author}\n"
    msg << "#########################\n"
    pulls.each do |pr|
      msg << "#{pr[:title]}, #{pr[:url]}\n"
    end
  end
  msg
end