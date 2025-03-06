require_relative './app'
require_relative './index'
require 'logger'
logger = Logger.new($stdout)
$stdout.sync = true
run AttendeeGate::App.rack(
  s3: Aws::S3::Client.new(logger:),
  s3_bucket: ENV.fetch('S3_BUCKET','rk-attendee-gate'),
  s3_key: ENV.fetch('S3_KEY','dev/dev.sqlite3'),
  hash_key: '',
)
