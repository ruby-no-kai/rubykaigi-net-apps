#!/usr/bin/env ruby
require 'ipaddr'
require 'json'

dev = IO.popen(%w(ip -o route get 8.8.8.8), 'r', &:read).match(/dev ([^ ]+)/)[1].chomp
addr = IO.popen([*%w(ip -o address show dev), dev], 'r', &:read).match(/inet ([^ ]+)/)[1].chomp
#addr = '10.33.137.193'
this = IPAddr.new(addr)

#ENV['DHCP_SERVER_IDS'] = '10.33.136.67/21,10.33.152.67/21'
candidates = ENV['DHCP_SERVER_IDS']&.then { _1.split(',') } || begin
  JSON.parse(File.read('/server-ids/server-ids.json')).fetch('server_ids')
end
warn(JSON.generate(this:, server_id_candidates: candidates))

candidates.each do |candidate|
  warn(JSON.generate(try: {candidate: candidate, this:}))
  if IPAddr.new(candidate).include?(this)
    warn(JSON.generate(server_id_chosen: candidate))
    puts candidate.split(?/)[0]
    exit
  end
end

warn(JSON.generate(server_id_unchosen: addr, this:))
puts addr.split(?/)[0]
