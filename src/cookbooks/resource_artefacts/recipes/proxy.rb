# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: proxy
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
fabio_user = node['fabio']['service_user']
poise_service_user fabio_user do
  group node['fabio']['service_group']
end

#
# DIRECTORIES
#

fabio_config_path = node['fabio']['conf_dir']
directory fabio_config_path do
  action :create
end

#
# INSTALL FABIO
#

fabio_install_path = node['fabio']['install_path']

remote_file 'fabio_release_binary' do
  path fabio_install_path
  source node['fabio']['release_url']
  checksum node['fabio']['checksum']
  owner 'root'
  mode '0755'
  action :create
end

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
fabio_service_name = node['fabio']['service_name']
systemd_service fabio_service_name do
  action :create
  after %w[network-online.target]
  description 'Fabio'
  documentation 'https://github.com/fabiolb/fabio'
  install do
    wanted_by %w[multi-user.target]
  end
  requires %w[network-online.target]
  service do
    exec_start "#{fabio_install_path} -cfg #{fabio_config_path}/fabio.properties"
    restart 'on-failure'
  end
  user fabio_user
end

# Make sure the fabio service doesn't start automatically. This will be changed
# after we have provisioned the box
service fabio_service_name do
  action :disable
end

#
# SETUP REDIRECT FROM PORT 80
#

#
# See here: https://serverfault.com/a/114934/239001 and https://serverfault.com/a/238565/239001
file '/etc/ufw/before.rules.tocopy' do
  action :create
  content <<~UFWRULES
    #
    # rules.before
    #
    # Rules that should be run before the ufw command line added rules. Custom
    # rules should be added to one of these chains:
    #   ufw-before-input
    #   ufw-before-output
    #   ufw-before-forward
    #

    # Redirect port 80 and port 443 so that fabio can get to it
    *nat
    :PREROUTING ACCEPT [0:0]
    -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 7080
    -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 7443
    COMMIT

    # Don't delete these required lines, otherwise there will be errors
    *filter
    :ufw-before-input - [0:0]
    :ufw-before-output - [0:0]
    :ufw-before-forward - [0:0]
    :ufw-not-local - [0:0]
    # End required lines


    # allow all on loopback
    -A ufw-before-input -i lo -j ACCEPT
    -A ufw-before-output -o lo -j ACCEPT

    # quickly process packets for which we already have a connection
    -A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    -A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    -A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # drop INVALID packets (logs these in loglevel medium and higher)
    -A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
    -A ufw-before-input -m conntrack --ctstate INVALID -j DROP

    # ok icmp codes for INPUT
    -A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
    -A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT
    -A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
    -A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
    -A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

    # ok icmp code for FORWARD
    -A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT
    -A ufw-before-forward -p icmp --icmp-type source-quench -j ACCEPT
    -A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT
    -A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT
    -A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT

    # allow dhcp client to work
    -A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT

    #
    # ufw-not-local
    #
    -A ufw-before-input -j ufw-not-local

    # if LOCAL, RETURN
    -A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN

    # if MULTICAST, RETURN
    -A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN

    # if BROADCAST, RETURN
    -A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN

    # all other non-local packets are dropped
    -A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
    -A ufw-not-local -j DROP

    # allow MULTICAST mDNS for service discovery (be sure the MULTICAST line above
    # is uncommented)
    -A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

    # allow MULTICAST UPnP for service discovery (be sure the MULTICAST line above
    # is uncommented)
    -A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

    # don't delete the 'COMMIT' line or these rules won't be processed
    COMMIT
  UFWRULES
end

#
# ALLOW FABIO THROUGH THE FIREWALL
#

firewall_rule 'http' do
  command :allow
  description 'Allow HTTP traffic'
  dest_port 80
  direction :in
end

firewall_rule 'https' do
  command :allow
  description 'Allow HTTPS traffic'
  dest_port 443
  direction :in
end

firewall_rule 'proxy-http' do
  command :allow
  description 'Allow proxy HTTP traffic'
  dest_port 7080
  direction :in
end

firewall_rule 'proxy-https' do
  command :allow
  description 'Allow proxy HTTPS traffic'
  dest_port 7443
  direction :in
end

firewall_rule 'proxy-ui-http' do
  command :allow
  description 'Allow Fabio UI traffic'
  dest_port 9998
  direction :in
end
