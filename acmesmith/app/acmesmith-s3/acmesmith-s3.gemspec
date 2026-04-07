Gem::Specification.new do |spec|
  spec.name = "acmesmith-s3"
  spec.version = '0'
  spec.authors = ["Kasumi Hanazuki"]
  spec.email = ["kasumi@rollingapple.net"]

  spec.summary = "Acmesmith Amazon S3 challenge responder"
  spec.description = "Acmesmith http-01 challenge responder for Amazon S3"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.files = Dir['lib/**/*.rb', base: __dir__]
  spec.require_paths = ["lib"]

  spec.add_dependency "acmesmith", "~> 2.0"
  spec.add_dependency "aws-sdk-s3", "~> 1.217"
  spec.add_dependency "rexml", "~> 3.4"
end
