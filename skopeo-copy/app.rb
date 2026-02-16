$stdout.sync = true

require 'json'
require 'base64'
require 'logger'
require 'open3'
require 'aws-sdk-ecr'
require 'aws-sdk-ecrpublic'

module SkopeoCopy
  ECR_PRIVATE_PATTERN = /\A(\d+)\.dkr\.ecr\.([^.]+)\.amazonaws\.com\z/
  ECR_PUBLIC_HOST = 'public.ecr.aws'
  AUTHFILE = '/tmp/containers-auth.json'

  Registry = Data.define(:host, :kind, :account_id, :region)

  def self.detect_registry(image_ref)
    host = image_ref.sub(%r{\A[a-z0-9+-]+://}, '').split('/').first
    case host
    when ECR_PRIVATE_PATTERN
      Registry.new(host:, kind: :ecr_private, account_id: $1, region: $2)
    when ECR_PUBLIC_HOST
      Registry.new(host:, kind: :ecr_public, account_id: nil, region: nil)
    end
  end

  def self.ecr_login_password(account_id:, region:)
    client = Aws::ECR::Client.new(region:, logger:)
    resp = client.get_authorization_token(registry_ids: [account_id])
    token = Base64.decode64(resp.authorization_data[0].authorization_token)
    _user, password = token.split(':', 2)
    password
  end

  # ECR Public endpoint is only available in us-east-1
  def self.ecr_public_login_password
    client = Aws::ECRPublic::Client.new(region: 'us-east-1', logger:)
    resp = client.get_authorization_token
    token = Base64.decode64(resp.authorization_data.authorization_token)
    _user, password = token.split(':', 2)
    password
  end

  def self.skopeo_login(registry:, password:)
    out, status = Open3.capture2e('skopeo', 'login', '--authfile', AUTHFILE, '--username', 'AWS', '--password-stdin', registry, stdin_data: password)
    logger.info("skopeo login #{registry}: #{out}")
    raise "skopeo login #{registry} failed (status=#{status.exitstatus}): #{out}" unless status.success?
  end

  def self.skopeo_copy(src:, dst:, arch: nil)
    cmd = ['skopeo', 'copy', '--authfile', AUTHFILE]
    cmd.push('--override-arch', arch) if arch
    cmd.push(src, dst)
    logger.info("skopeo copy #{src} #{dst}")
    out, status = Open3.capture2e(*cmd)
    logger.info("skopeo copy: #{out}")
    raise "skopeo copy failed (status=#{status.exitstatus}): #{out}" unless status.success?
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.perform(event)
    params = event.fetch('skopeo_copy')
    src = params.fetch('src')
    dst = params.fetch('dst')

    registries = [detect_registry(src), detect_registry(dst)].compact.uniq
    registries.each do |reg|
      case reg.kind
      when :ecr_private
        password = ecr_login_password(account_id: reg.account_id, region: reg.region)
        skopeo_login(registry: reg.host, password:)
      when :ecr_public
        password = ecr_public_login_password
        skopeo_login(registry: reg.host, password:)
      end
    end

    arch = params['arch']
    skopeo_copy(src:, dst:, arch:)

    image_url = dst.sub(%r{\A[a-z0-9+-]+://}, '')
    {status: 'ok', src:, dst:, image_url:}
  end
end

def handler(event:, context:)
  SkopeoCopy.perform(event)
end
