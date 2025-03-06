$stdout.sync = true

module AttendeeGate
  module Handlers
    @logger = Logger.new($stdout)

    Environ = Data.define(:hash_key, :tito_api_token) do
      def inspect
        "#<Environ #{self.__id__}>"
      end
    end

    def self.generate_data(event:, context:)
      require_relative './generator'
      Generator.handle(event:, context:, environ:)
    end

    def self.http(event:, context:)
      @app ||= begin
        require_relative './app'
        require 'apigatewayv2_rack'
        require 'aws-sdk-s3'
        App.rack(
          s3: Aws::S3::Client.new(logger: @logger),
          s3_bucket: ENV.fetch('S3_BUCKET'),
          s3_key: ENV.fetch('S3_KEY'),
          hash_key: '',
        )
      end
      Apigatewayv2Rack.handle_request(event:, context:, app: @app)
    end

    def self.environ
      require 'aws-sdk-ssm'
      ssm = Aws::SSM::Client.new(logger: @logger)
      Environ.new(
        hash_key: ENV.fetch('HASH_KEY') { ssm.get_parameter(name: "#{ENV.fetch('SSM_PREFIX')}HASH_KEY", with_decryption: true).parameter.value },
        tito_api_token: ENV.fetch('TITO_API_TOKEN') { ssm.get_parameter(name: "#{ENV.fetch('SSM_PREFIX')}TITO_API_TOKEN", with_decryption: true).parameter.value },
      )
    end
  end
end
