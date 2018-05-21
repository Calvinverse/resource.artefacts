# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: provisioning
#
# Copyright 2017, P. van der Velde
#

file '/etc/init.d/provision_image.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionImage {
      sudo systemctl enable nexus.service
    }
  BASH
  mode '755'
end

service 'provision.service' do
  action [:enable]
end
