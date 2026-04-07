require 'acmesmith/challenge_responders/base'

require 'aws-sdk-s3'

module Acmesmith
  module ChallengeResponders
    class S3 < Base
      def initialize(bucket:, prefix: '')
        @s3 = Aws::S3::Resource.new
        @bucket = @s3.bucket(bucket)
        @prefix = prefix
      end

      def support?(type)
        type == 'http-01'
      end

      def respond(domain, challenge)
        obj = object_for(challenge)
        puts "=> Uploading #{obj.key} for #{domain}"
        obj.put(
          content_type: 'text/plain',
          body: challenge.file_content,
        )
      end

      def cleanup(domain, challenge)
        obj = object_for(challenge)
        puts "=> Deleting #{obj.key} for #{domain}"
        obj.delete
      end

      private def object_for(challenge)
        @bucket.object("#@prefix#{challenge.filename}")
      end
    end
  end
end
