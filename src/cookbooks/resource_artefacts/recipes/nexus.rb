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

# Make sure the fabio service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
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

file '/etc/consul/conf.d/nexus.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
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
