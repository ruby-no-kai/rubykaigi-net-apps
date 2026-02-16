require 'bundler/setup'
require_relative 'lib/rk_logger'
require 'sinatra/base'

class TestApp < Sinatra::Base
  get '/' do
    content_type :text
    pp env
    SemanticLogger['TestApp'].info('AAAA')
    logger.info('BBBB')
    raise
    "Hello, World!"
  end
end

use RkLogger::RackLogger
run TestApp
