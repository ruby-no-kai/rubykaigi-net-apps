require 'httpx'
require 'base64'
require 'openssl'

BASE_URL = ENV.fetch('BASE_URL')
HASH_KEY = ENV.fetch('HASH_KEY')
HASH_ALG = 'sha384'

def validate(email:, code:)
  HTTPX.post(
    "#{BASE_URL}/validate",
    form: {
      email_hashed: Base64.urlsafe_encode64(OpenSSL::HMAC.digest(HASH_ALG, HASH_KEY, email)),
      code:,
    },
  ).tap(&:raise_for_status).json
end

pp validate(email: ARGV[0], code: ARGV[1])
