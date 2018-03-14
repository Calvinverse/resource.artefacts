# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_artefacts::firewall'

include_recipe 'resource_artefacts::meta'
include_recipe 'resource_artefacts::provisioning'

include_recipe 'resource_artefacts::java'
include_recipe 'resource_artefacts::nexus'
include_recipe 'resource_artefacts::nexus_artefacts'
include_recipe 'resource_artefacts::nexus_docker'
include_recipe 'resource_artefacts::nexus_gems'
include_recipe 'resource_artefacts::nexus_npm'
include_recipe 'resource_artefacts::nexus_nuget'
include_recipe 'resource_artefacts::nexus_service'
