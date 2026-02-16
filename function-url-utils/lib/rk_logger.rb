# frozen_string_literal: true
require 'semantic_logger'
require 'rack/body_proxy'
require 'rack/utils'
require 'rack/request'
require 'sinatra/base'

class Sinatra::Base
  set :logging, nil
  set :dump_errors, false
end

$stdout.sync = true
if ENV['AWS_LAMBDA_RUNTIME_API'] || ENV['LOG_IN_JSON']
  io = if defined?(AwsLambdaRIC::TelemetryLogger) && AwsLambdaRIC::TelemetryLogger.respond_to?(:telemetry_log_sink) && AwsLambdaRIC::TelemetryLogger.telemetry_log_sink
    AwsLambdaRIC::TelemetryLogger.telemetry_log_sink
  else
    $stdout
  end
  SemanticLogger.add_appender(io: io, formatter: :json)
else
  SemanticLogger.add_appender(io: $stdout, formatter: :color) unless SemanticLogger.appenders.console_output?
end

SemanticLogger.application = ENV['AWS_LAMBDA_FUNCTION_NAME'] if ENV['AWS_LAMBDA_FUNCTION_NAME'] && SemanticLogger.application == 'Semantic Logger'

module RkLogger
  class RackLogger
    def initialize(app, logger: SemanticLogger['RkRack'], started_request_log_level: :debug, log_query_string: true)
      @app = app
      @logger = logger
      @started_request_log_level = started_request_log_level
      @log_query_string = log_query_string
    end

    def call(env)
      began_at = Rack::Utils.clock_time
      env['rack.logger'] = @logger
      env['sinatra.commonlogger'] = true
      request_line, tags = request_line_for(env)
      @logger.tagged(tags) do
        @logger.__send__(@started_request_log_level) { {message: 'Started', payload: request_line} }
        status, headers, body = response = @app.call(env)
        response[2] = Rack::BodyProxy.new(body) { log_finish(env, request_line, tags, status, headers, began_at) }
        response
      end
    end

    def request_line_for(env)
      request = Rack::Request.new(env)
      context = env['apigatewayv2.request']&.context
      [
        {
          method: request.request_method,
          path: request.path_info,
          query: @log_query_string ? request.query_string : nil,
          lambda_function_arn: context&.invoked_function_arn,
          lambda_function_version: context&.function_version,
          request_length: env['CONTENT_LENGTH'],
        }.compact,
        {
          method: request.request_method,
          path: request.path_info,
          query: @log_query_string ? request.query_string : nil,
          request_id: context&.aws_request_id,
          ip: request.ip,
          xff: env['HTTP_X_FORWARDED_FOR'],
          cip: env['REMOTE_ADDR'],
        }.compact,
      ]
    end

    SILENCED_ERRORS = [
      "Rack::QueryParser::InvalidParameterError",
      "Rack::QueryParser::ParameterTypeError",
      "Sinatra::NotFound",
    ].freeze

    def log_finish(env, request_line, tags, status, headers, began_at)
      ended_at = Rack::Utils.clock_time
      duration = ended_at - began_at
      @logger.tagged(tags) do
        request_line[:response_length] = headers['content-length']&.to_i
        request_line[:status] = status.to_s
        @logger.info do
          {
            message: 'Finished',
            duration: duration,
            payload: request_line,
          }
        end
        error = env['rack.exception'] || env['sinatra.error']
        if error && !SILENCED_ERRORS.include?(error.class.name)
          @logger.error do
            {
              message: 'Exception occurred',
              exception: error,
              duration: duration,
              payload: request_line,
            }
          end
        end
      end
    end
  end
end
