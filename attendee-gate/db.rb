require 'sqlite3'
require 'securerandom'
require 'openssl'

module AttendeeGate
  class DB
    EPOCH = 2
    HASH_ALG = 'sha384'

    Attendee = Data.define(:code, :email_hashed, :state, :release) do
      def self.make(code:, email:, state:, release:, hash_key:)
        new(
          code:,
          email_hashed: DB.hash(hash_key, email),
          state:,
          release:,
        )
      end

      def self.from_row(row)
        new(
          code: row.fetch('code'),
          email_hashed: row.fetch('email_hashed').to_s,
          state: row.fetch('state'),
          release: row.fetch('release'),
        )
      end
    end

    def self.open(path:, create: false, **kwargs)
      FileUtils.mkdir_p File.dirname(path) if path
      state = new(path:, **kwargs)
      state.ensure_schema!(create:)
      state
    end

    # @param path [String, #to_path, nil]
    def initialize(path:, hash_key: "himitsujanaikamo")
      @hash_key = hash_key
      @db = SQLite3::Database.new(
        path || ':memory:',
        {
          results_as_hash: true,
          strict: true, # Disable SQLITE_DBCONFIG_DQS_DDL, SQLITE_DBCONFIG_DQS_DML
        }
      )
    end

    def close
      @db.close
    end

    def inspect
      "#<#{self.class.name} #{self.__id__}, #{current.inspect}>"
    end

    attr_reader :db

    def current
      epoch_tables = @db.execute("select * from sqlite_schema where type = 'table' and name = 'attendeegate_epoch'")
      return nil if epoch_tables.empty?
      @db.execute(%{select * from "attendeegate_epoch" order by "epoch" desc limit 1}).first
    end

    def current_epoch
      current&.dig('epoch')
    end

    def ensure_schema!(create: false)
      if current_epoch == EPOCH
        return
      elsif !create
        raise "schema version mismatch"
      end

      @db.execute_batch <<~SQL
        drop table if exists "attendeegate_epoch";
        create table attendeegate_epoch (
          "epoch" integer not null,
          "finger" text not null,
          "created_at" integer not null
        ) strict;
      SQL

      @db.execute_batch <<~SQL
        drop table if exists "attendees";
        create table "attendees" (
          code text not null unique,
          email_hashed blob not null default '',
          release text not null,
          state text not null
        ) strict;
      SQL
      @db.execute_batch <<~SQL
        drop index if exists "idx_attendees_code";
        create unique index "idx_attendees_code" on "attendees" ("code");
      SQL
      @db.execute_batch <<~SQL
        drop index if exists "idx_attendees_email";
        create index "idx_attendees_email" on "attendees" ("email_hashed");
      SQL

      @db.execute(%{insert into "attendeegate_epoch" ("epoch", "finger", "created_at") values (?,?,?)}, [EPOCH, SecureRandom.urlsafe_base64(12),Time.now.to_i])
    end

    def insert_attendee(code:, email:, state:, release:)
      attendee = Attendee.make(code:, email:, state:, release:, hash_key: @hash_key)
      @db.execute(<<~SQL, [attendee.code, attendee.email_hashed.to_blob, attendee.state, attendee.release])
        insert into "attendees" ("code", "email_hashed", "state", "release") values (?, ?, ?, ?)
      SQL
    end

    def find_attendee_by_code(code)
      @db.execute(%{select * from "attendees" where "code" = ?}, [code])[0]&.then { Attendee.from_row(_1) }
    end

    def find_attendees_by_email(email)
      @db.execute(%{select * from "attendees" where "email_hashed" = ? order by code asc}, [hash(@hash_key, email)]).map { Attendee.from_row(_1) }
    end

    def find_attendees_by_email_hashed(email_hashed)
      @db.execute(%{select * from "attendees" where "email_hashed" = ? order by code asc}, [email_hashed]).map { Attendee.from_row(_1) }
    end

    private def hash(...)
      self.class.hash(...)
    end

    def self.hash(hash_key, data)
      data ? OpenSSL::HMAC.digest('sha384', hash_key, data) : ''
    end
  end
end
