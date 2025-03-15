require 'httpx'
require 'uri'
require 'aws-sdk-s3'

module AttendeeGate
  class Metrics
    TITO_BASE_URL = 'https://api.tito.io/v3'
    TITO_CHECKIN_URL = 'https://checkin.tito.io'

    CheckinList = Data.define(:id, :slug, :event, :title) do
      alias inspect_ inspect
      def inspect
        inspect_.gsub(/"chk_[^"]+/, '"chk_...')
      end
    end
    Ticket = Struct.new(:id, :release_title, :checkin, keyword_init: true)
    DataDimension = Data.define(:event_slug, :list_id, :list_title, :release_title) do
      def to_prom
        %|event_slug="#{event_slug}",list_id="#{list_id}",list_title="#{list_title}",release_title="#{release_title}"|
      end
    end
    DataPoint = Struct.new(:dimension, :total_value, :checkin_value, keyword_init: true) do
      def to_prom
        [
          %|tito_checkin_list_total{#{dimension.to_prom}} #{total_value}|,
          %|tito_checkin_list_completed{#{dimension.to_prom}} #{checkin_value}|,
        ].join("\n")
      end
    end

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
      p(bucket: @bucket, key: @key, event_slug: @event_slug)

      @http = HTTPX.with(
        headers: {
          'user-agent' => "attendee-gate (+https://github.com/ruby-no-kai/rubykaigi-net-apps/tree/main/attendee-gate)",
          'authorization' => "Token token=#{environ.tito_api_token}",
        },
      )
    end

    def perform
      data = {}
      tito_checkin_lists.each do |list|
        tickets = {}
        fetch_tito_tickets(list) do |page|
          page.each do |ticket|
            tickets[ticket.fetch('id')] = Ticket.new(
              id: ticket.fetch('id'),
              release_title: ticket.fetch('release_title'),
              checkin: false,
            )
          end
        end
        fetch_tito_checkins(list) do |page|
          page.each do |checkin|
            t = tickets[checkin.fetch('ticket_id')]
            if t
              t.checkin = true
            else
              warn "checkin for unknown ticket: #{checkin.inspect}"
            end
          end
        end
        tickets.each_value do |t|
          dimension = DataDimension.new(
            event_slug: @event_slug,
            list_id: list.id,
            list_title: list.title,
            release_title: t.release_title,
          )
          data[dimension] ||= DataPoint.new(dimension: dimension, total_value: 0, checkin_value: 0)
          data[dimension].total_value += 1
          data[dimension].checkin_value += 1 if t.checkin
        end
      end

      prom = data.each_value.map do |dp|
        dp.to_prom
      end.concat(["tito_checkin_updated_at #{Time.now.to_i}", '']).join("\n")

      s3 = Aws::S3::Client.new
      s3.put_object(bucket: @bucket, key: @key, body: prom, content_type: 'text/plain; version=0.0.4')
    end

    private def tito_checkin_lists
      @http.get("#{TITO_BASE_URL}/#{@event_slug}/checkin_lists").json.fetch('checkin_lists').filter_map do |checkin_list|
        next if checkin_list.fetch('state') == 'expired'
        CheckinList.new(
          id: checkin_list.fetch('id'),
          slug: checkin_list.fetch('slug'),
          event: @event_slug,
          title: checkin_list.fetch('title'),
        )
      end
    end

    private def fetch_tito_checkins(list)
      pagenum = 1
      total_items = 0
      loop do
        p(kind: :checkins, list:,pagenum:,total_items:)
        resp = @http.get("#{TITO_CHECKIN_URL}/checkin_lists/#{list.slug}/checkins", params: { 'page' => pagenum }, headers: { 'Accept' => 'application/json' })
        resp.raise_for_status
        page = resp.json
        total_items += page.size
        break if page.empty?
        yield page
        pagenum += 1
      end
    end

    private def fetch_tito_tickets(list)
      pagenum = 1
      total_items = 0
      loop do
        p(kind: :tickets, list:,pagenum:,total_items:)
        resp = @http.get("#{TITO_CHECKIN_URL}/checkin_lists/#{list.slug}/tickets", params: { 'page' => pagenum }, headers: { 'Accept' => 'application/json' })
        resp.raise_for_status
        page = resp.json
        total_items += page.size
        break if page.empty?
        yield page
        pagenum += 1
      end
    end
  end
end

if $0 == __FILE__
  require_relative './index'
  AttendeeGate::Metrics.new(
    bucket: ENV.fetch('S3_BUCKET','rk-attendee-gate'),
    key: ENV.fetch('S3_KEY','dev/prometheus/2024'),
    event_slug: ENV.fetch('TITO_EVENT_SLUG', 'rubykaigi/2024'),
    environ: AttendeeGate::Handlers.environ,
  ).perform
end
