# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['nexus']['service_user'] do
  group node['nexus']['service_group']
end

#
# INSTALL NEXUS
#

nexus3 'nexus' do
  action :install
  group node['nexus']['service_group']
  user node['nexus']['service_user']
end

# Disable anonymous access
nexus3_api 'anonymous' do
  action :run
  content 'security.setAnonymousAccess(false)'
end

#
# ALLOW NEXUS THROUGH THE FIREWALL
#

firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port 8081
  direction :in
end

#
# CONNECT TO CONSUL
#

# Create the user which is used by consul for the health check
nexus3_api 'role-metrics' do
  content "security.addRole('nx-metrics', 'nx-metrics'," \
    " 'User with privileges to allow read access to the Nexus metrics'," \
    " ['nx-metrics-all'], ['nx-anonymous'])"
  action :run
end

nexus3_api 'userConsul' do
  action :run
  content "security.addUser('consul.health', 'Consul', 'Health', 'consul.health@example.com', true, 'consul.health', ['nx-metrics'])"
end

file '/etc/consul/conf.d/nexus.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : []}
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus API ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "active",
            "read",
            "write"
          ]
        },
        {
          "checks" :[
            {
              "header": { "Authorization" : []}
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus API ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "management",
            "edgeproxyprefix-/artefacts"
          ]
        }
      ]
    }
  JSON
end

#
# DISABLE THE SERVICE
#

# Make sure the nexus service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
end

# Update the systemd service configuration for Nexus so that we can set
# the number of file handles for the given user
# See here: https://help.sonatype.com/display/NXRM3/System+Requirements#filehandles
systemd_service 'nexus' do
  action :create
  after %w[network.target]
  description 'nexus service'
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start '/opt/nexus/bin/nexus start'
    exec_stop '/opt/nexus/bin/nexus stop'
    limit_nofile 65_536
    restart 'on-abort'
    type 'forking'
    user node['nexus']['service_user']
  end
end
