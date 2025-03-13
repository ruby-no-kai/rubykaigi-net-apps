#!/usr/bin/env ruby
require 'bundler/setup'
require 'aws-sdk-rds'
require 'open-uri'

REGION =  ENV.fetch('AWS_REGION')
File.write '/app/rds-ca-bundle.pem', URI.open("https://truststore.pki.rds.amazonaws.com/#{REGION}/#{REGION}-bundle.pem", 'r', &:read)
@auth = Aws::RDS::AuthTokenGenerator.new(credentials: Aws::CredentialProviderChain.new.resolve)

def run(host:, name:)
  user_name =ENV.fetch('KEA_ADMIN_DB_USER')
  token = @auth.generate_auth_token(region: REGION, endpoint: "#{host}:3306", expires_in: 900, user_name: user_name)
  ENV['KEA_ADMIN_DB_PASSWORD'] = token
  puts ">>>> kea-admin db-upgrade -n #{name} -h #{host}"
  system(
    *%w(kea-admin db-upgrade mysql),
    '-h', host,
    '-u', user_name,
    '-n', name,
    '-x', "--enable-cleartext-plugin --ssl-ca /app/rds-ca-bundle.pem",
    exception: true
  )
end

run(host: ENV.fetch('LEASE_DATABASE_HOST'), name: ENV.fetch('LEASE_DATABASE_NAME'))
run(host: ENV.fetch('HOSTS_DATABASE_HOST'), name: ENV.fetch('HOSTS_DATABASE_NAME'))
