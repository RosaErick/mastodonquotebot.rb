require 'mastodon'
require 'dotenv/load'
require 'rufus-scheduler'
require 'faraday'
require 'json'
require 'logger'
# require 'airrecord'

#  Logger
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

logger.info "Initializing Mastodon client..."
# Mastodon Client
client = Mastodon::REST::Client.new(
  base_url: ENV['MASTODON_BASE_URL'],
  bearer_token: ENV['MASTODON_ACCESS_TOKEN']
)
logger.info "Mastodon client initialized."

# Comment out the Airtable class definition
# class Quote < Airrecord::Table
#   self.base_key = ENV['AIRTABLE_BASE_ID']
#   self.table_name = 'Quotes'
# end

# Scheduler
scheduler = Rufus::Scheduler.new

def fetch_quote_from_file(logger)
  logger.debug "Fetching quote from file..."
  quotes = File.readlines('quotes.txt').map(&:strip).reject(&:empty?)
  quote = quotes.sample
  if quote.nil? || quote.empty?
    logger.error "No valid quote found in the file."
    nil
  else
    quote
  end
rescue Errno::ENOENT
  logger.error "File not found"
  nil
end


def fetch_quote_from_api(logger)
  logger.debug "Fetching quote from API..."
  response = Faraday.get('https://api.quotable.io/random')
  if response.status == 200
    data = JSON.parse(response.body)
    "#{data['content']} — #{data['author']}"
  else
    logger.error "Failed to fetch quote from API."
    nil
  end
rescue StandardError => e
  logger.error "Error fetching quote from API: #{e.message}"
  nil
end

# airtable
# def fetch_quote_from_airtable(logger)
#   logger.debug "Fetching quote from Airtable..."
#   quotes = Quote.all.map { |record| "#{record['Text']} — #{record['Author']}" }
#   quotes.sample
# rescue StandardError => e
#   logger.error "Error fetching quote from Airtable: #{e.message}"
#   nil
# end

def fetch_quote(logger)
  source = ENV['QUOTES_SOURCE']
  case source
  when 'file'
    fetch_quote_from_file(logger)
  when 'api'
    fetch_quote_from_api(logger)
  # when 'airtable'
    # fetch_quote_from_airtable(logger)
  else
    logger.error "Invalid QUOTES_SOURCE specified."
    nil
  end
end

def post_quote(client, logger)
  quote = fetch_quote(logger)
  if quote && !quote.empty?
    logger.info "Fetched quote: #{quote}"
    client.create_status(quote.dup)  # duplicate to avoid frozenerror
    logger.info "Successfully posted quote: #{quote}"
  else
    logger.warn "Skipping empty or invalid quote."
  end
rescue Mastodon::Error => e
  logger.error "Error posting to Mastodon: #{e.message}"
rescue StandardError => e
  logger.error "Unexpected error: #{e.message}"
end


interval = ENV['POST_INTERVAL'].to_i

if interval <= 0
  logger.error "Invalid POST_INTERVAL specified."
  exit
end

# Initial immediate post
post_quote(client, logger)

# Schedule recurring posts
scheduler.every "#{interval}m" do
  post_quote(client, logger)
end

logger.info "Bot has started"

# Keep the script running
scheduler.join
