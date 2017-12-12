#! env ruby

require 'rufus-scheduler'
require 'rest-client'
require 'logging'
require 'mongo'
require 'json'
require 'time'

# Variables
mongo_hostname = ENV['MONGO_HOSTNAME'] || '127.0.0.1'
mongo_port     = ENV['MONGO_PORT']     || '27017'
mongo_database = ENV['MONGO_DATABASE'] || 'main'

# Set up logging
logger = Logging.logger(STDOUT)
logger.level = :debug
logger.debug "Logging initialised to STDOUT"

# Set up scheduler
scheduler = Rufus::Scheduler.new

logger.stdout "Mongodb hostname: #{mongo_hostname}"
logger.stdout "Mongodb port: #{mongo_port}"
logger.stdout "Mongodb database: #{mongo_database}"

# Create mongodb connection
Mongo::Logger.logger.level = ::Logger::FATAL
logger.info "Connecting to mongod: #{mongo_hostname}:#{mongo_port}; Database: #{mongo_database}"
mongo = Mongo::Client.new([ "#{mongo_hostname}:#{mongo_port}" ], :database => mongo_database)
logger.debug "Testing mongoDB connection"
logger.debug "Mongodb DB names: #{mongo.database_names}"

# Create a document for each stat
logger.info "Initialising data structures"

statistics = [
  'presale',
  'btc_received',
  'ltc_received',
  'eth_received',
  'usd_value',
  'nav_per_token',
  'backers',
]

statistics.each do |st|
  logger.debug "Checking statistic: #{st}"
  if mongo[:statistics].find(name: st).count == 0
    logger.debug "Creating statistic: #{st}"
    mongo[:statistics].insert_one({
      name: st,
      value: nil,
    })
  end
end

scheduler.every "3s" do
  response = JSON.parse(RestClient.get('https://www.crypto20.com/status').body)

  if response.is_a? Hash
    logger.debug "Updating values"

    # Set all values
    mongo[:statistics].update_one({name: 'presale'},
      { '$set' => { value: response['presale']}})
    mongo[:statistics].update_one({name: 'btc_received'},
      { '$set' => { value: response['btc_received']}})
    mongo[:statistics].update_one({name: 'ltc_received'},
      { '$set' => { value: response['ltc_received']}})
    mongo[:statistics].update_one({name: 'eth_received'},
      { '$set' => { value: response['eth_received']}})
    mongo[:statistics].update_one({name: 'usd_value'},
      { '$set' => { value: response['usd_value']}})
    mongo[:statistics].update_one({name: 'nav_per_token'},
      { '$set' => { value: response['nav_per_token']}})
    mongo[:statistics].update_one({name: 'backers'},
      { '$set' => { value: response['backers']}})

    # Set the values for all the holdings
    response['holdings'].each do |holding|
      mongo[:holdings].update_one(
         { name: holding['name'] },
         holding,
         { upsert: true }
      )
    end
  else
    logger.error "Failed to retrieve status from crypto20.com"
  end
end

scheduler.every "10m" do
  response = JSON.parse(RestClient.get('https://www.crypto20.com/status').body)

  if response.is_a? Hash
    logger.debug "Adding historical data"

    record_id = mongo[:historical_value].insert_one({
      value: response['usd_value'],
      time: Time.now.to_i,
      })

    record_id = mongo[:historical_nav].insert_one({
      value: response['nav_per_token'],
      time: Time.now.to_i,
      })


    record_id = mongo[:historical_holdings].insert_one({
      holdings: response['holdings'],
      time: Time.now.to_i,
      })

  else
    logger.error "Failed to retrieve status from crypto20.com"
  end
end

logger.info "All schedules created, running..."

while true
  sleep 100
end
