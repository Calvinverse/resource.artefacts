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
