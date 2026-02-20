require_relative './db'
require 'base64'
require 'aws-sdk-s3'
require 'sinatra/base'

module AttendeeGate
  class App < Sinatra::Base
    CONTEXT_NAME = 'attendeegate.ctx'
    DB_NAME = 'attendeegate.db'

    class DataCache
      STALE_AFTER = 15
      Head = Data.define(:last_modified, :etag, :ts) do
        def self.from_s3_response(r)
          new(
            last_modified: r.last_modified,
            etag: r.etag,
            ts: Time.now,
          )
        end
      end

      def initialize(context)
        @context = context
        @db = nil
        @file = nil
        @head = nil
      end

      attr_reader :context

      def value
        return @db unless stale?
        @db&.close
        @file&.unlink
        @db = nil
        @file, @db, @head = fetch_db
        @db
      end

      def stale?
        return true unless @db && @head
        return false if (Time.now - @head.ts) < STALE_AFTER
        Head.from_s3_response(s3.head_object(bucket: context.s3_bucket, key: context.s3_key)) != @head
      end

      private def fetch_db
        file = Tempfile.new
        r = s3.get_object(bucket: context.s3_bucket, key: context.s3_key, response_target: file)
        db = DB.open(path: file.path, hash_key: context.hash_key)
        @file, @db, @head = file, db, Head.from_s3_response(r)
      end

      # @return [Aws::S3::Client]
      private def s3
        context.s3
      end
    end

    Context = Data.define(:s3, :s3_bucket, :s3_key, :hash_key) do
      def inspect
        "#<#{self.class.name} #{self.__id__}>"
      end
    end

    def self.rack(...)
      ctx = Context.new(...)
      db = DataCache.new(ctx)
      lambda do |env|
        env[CONTEXT_NAME] = ctx
        env[DB_NAME] = db
        self.call(env)
      end
    end

    helpers do
      def context
        env.fetch(CONTEXT_NAME)
      end

      def db
        env.fetch(DB_NAME).value
      end
    end

    post '/validate' do
      given_email_hashed = params[:email_hashed]&.to_s&.then { Base64.urlsafe_decode64(_1) } rescue nil
      given_code = params[:code]&.to_s&.then { _1.include?('-') ? _1 : "#{_1}-1" }
      halt(400, "email_hashed is required") if !given_email_hashed || given_email_hashed.empty?
      halt(400, "code is required") if !given_code || given_code.empty?

      result = nil

      cand = db.find_attendee_by_code(given_code)
      if cand
        result = OpenSSL.fixed_length_secure_compare(cand.email_hashed, given_email_hashed) ? "ok" : "email_mismatch"
      end

      unless result
        cands = db.find_attendees_by_email(given_email_hashed)
        result = cands.empty? ? "not_found" : "code_mismatch"
      end

      content_type :json
      JSON.pretty_generate(
        meta: {
          db: db.current.to_h,
        },
        result:,
        ticket: result == 'ok' ? {
          release: cand.release,
        } : nil,
      )
    end
  end
end
