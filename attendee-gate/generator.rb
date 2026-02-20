require 'tempfile'
require 'httpx'
require 'uri'
require 'aws-sdk-s3'
require_relative './db'

module AttendeeGate
  class Generator
    TITO_BASE_URL = 'https://api.tito.io/v3'

    def self.handle(event:, context:, environ:)
      new(
        bucket: event.fetch('bucket'),
        key: event.fetch('key'),
        event_slug: event.fetch('event_slug'),
        environ:,
      ).perform
    end

    def initialize(bucket:, key:, event_slug:, environ:)
      @bucket = bucket
      @key = key
      @event_slug = event_slug
      @envrion = environ

      @tempfile = Tempfile.new
      @db = DB.open(path: @tempfile.path, create: true, hash_key: environ.hash_key)

      @http = HTTPX.with(
        headers: {
          'user-agent' => "attendee-gate (+https://github.com/ruby-no-kai/rubykaigi-net-apps/tree/main/attendee-gate)",
          'authorization' => "Token token=#{environ.tito_api_token}",
        },
      )
    end

    def perform
      last_page = nil
      fetch_tito_tickets do |page|
        page.fetch('tickets').each do |ticket|
          code = ticket.fetch('reference')
          # XXX: sometime Tito API returns duplicated entry
          next if last_page&.fetch('tickets')&.find { |t| t.fetch('reference') == code } == ticket
          @db.insert_attendee(
            code:,
            email: ticket.fetch('email'),
            state: ticket.fetch('state'),
            release: tito_releases.fetch(ticket.fetch('release_id')).fetch('title'),
          )
        end
        last_page = page
      end

      @tempfile.rewind
      s3 = Aws::S3::Client.new
      s3.put_object(bucket: @bucket, key: @key, body: @tempfile, content_type: 'application/vnd.sqlite3', metadata: {'finger' => @db.current.fetch('finger')})
    end

    private def fetch_tito_tickets
      pagenum = nil
      total_items = 0
      loop do
        p(pagenum:,total_items:)
        resp= @http.get("#{TITO_BASE_URL}/#{@event_slug}/tickets", params: { 'version' => '3.1', 'page[size]' => 100, 'page[number]' => pagenum })
        resp.raise_for_status
        page = resp.json
        total_items += page['tickets']&.size || 0
        yield page
        pagenum = page.dig('meta', 'next_page')
        break unless pagenum
      end
    end

    private def tito_releases
      @tito_releases ||= begin
        releases = {}
        fetch_tito_releases do |page|
          page.fetch('releases').each do |release|
            releases[release.fetch('id')] = release
          end
        end
        releases
      end
    end

    private def fetch_tito_releases
      pagenum = nil
      total_items = 0
      loop do
        p(pagenum:,total_items:)
        resp= @http.get("#{TITO_BASE_URL}/#{@event_slug}/releases", params: { 'version' => '3.1', 'page[size]' => 100, 'page[number]' => pagenum })
        resp.raise_for_status
        page = resp.json
        total_items += page['releases']&.size || 0
        yield page
        pagenum = page.dig('meta', 'next_page')
        break unless pagenum
      end
    end
  end
end

if $0 == __FILE__
  require_relative './index'
  AttendeeGate::Generator.new(
    bucket: ENV.fetch('S3_BUCKET','rk-attendee-gate'),
    key: ENV.fetch('S3_KEY','dev/dev.sqlite3'),
    event_slug: ENV.fetch('TITO_EVENT_SLUG', 'rubykaigi/2026'),
    environ: AttendeeGate::Handlers.environ,
  ).perform
end
