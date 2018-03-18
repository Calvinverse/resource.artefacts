# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_service
#
# Copyright 2018, P. van der Velde
#

#
# UPDATE THE SERVICE
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
    user node['nexus3']['service_user']
  end
end

#
# SET THE PROXY PATH
#

nexus_data_path = node['nexus3']['data']
nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file "#{nexus_data_path}/etc/nexus.properties" do
  action :create
  content <<~PROPERTIES
    # Jetty section
    application-port=#{nexus_management_port}
    application-host=0.0.0.0
    nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-requestlog.xml
    nexus-context-path=#{nexus_proxy_path}
  PROPERTIES
end
