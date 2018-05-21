# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: firewall
#
# Copyright 2017, P. van der Velde
#

firewall 'default' do
  action :install
end

# Because the chef firewall cookbook is designed to set all the rules on the firewall in one go and nuke
# any existing ones we have to reset all the base image rules

#
# SSH
#

firewall_rule 'ssh' do
  command :allow
  description 'Allow SSH traffic'
  dest_port 22
  direction :in
end

#
# CONSUL
#

firewall_rule 'consul-http' do
  command :allow
  description 'Allow Consul HTTP traffic'
  dest_port 8500
  direction :in
end

firewall_rule 'consul-dns' do
  command :allow
  description 'Allow Consul DNS traffic'
  dest_port 8600
  direction :in
  protocol :udp
end

firewall_rule 'consul-rpc' do
  command :allow
  description 'Allow Consul rpc LAN traffic'
  dest_port 8300
  direction :in
end

firewall_rule 'consul-serf-lan-tcp' do
  command :allow
  description 'Allow Consul serf LAN traffic on the TCP port'
  dest_port 8301
  direction :in
  protocol :tcp
end

firewall_rule 'consul-serf-lan-udp' do
  command :allow
  description 'Allow Consul serf LAN traffic on the UDP port'
  dest_port 8301
  direction :in
  protocol :udp
end

firewall_rule 'consul-serf-wan-tcp' do
  command :allow
  description 'Allow Consul serf WAN traffic on the TCP port'
  dest_port 8302
  direction :in
  protocol :tcp
end

firewall_rule 'consul-serf-wan-udp' do
  command :allow
  description 'Allow Consul serf WAN traffic on the UDP port'
  dest_port 8302
  direction :in
  protocol :udp
end

#
# TELEGRAF
#

firewall_rule 'telegraf-statsd' do
  command :allow
  description 'Allow Telegraf statsd traffic'
  dest_port 8125
  direction :in
end

#
# UNBOUND
#

firewall_rule 'unbound-dns-udp' do
  command :allow
  description 'Allow Unbound DNS (UDP) proxy traffic'
  dest_port 53
  direction :in
  protocol :udp
end

firewall_rule 'unbound-dns-tcp' do
  command :allow
  description 'Allow Unbound DNS (TCP) proxy traffic'
  dest_port 53
  direction :in
  protocol :tcp
end
