# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: meta
#
# Copyright 2017, P. van der Velde
#

resource_name = node['resource']['name']
resource_short_name = node['resource']['name_short']
ruby_block 'set_environment_product_name' do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    file.insert_line_if_no_match("RESOURCE_NAME=#{resource_name}", "RESOURCE_NAME=#{resource_name}")
    file.insert_line_if_no_match("RESOURCE_SHORT_NAME=#{resource_short_name}", "RESOURCE_SHORT_NAME=#{resource_short_name}")
    file.search_file_replace_line('STATSD_ENABLED_SERVICES=consul', 'STATSD_ENABLED_SERVICES=consul')
    file.write_file
  end
end

resource_version_major = node['resource']['version_major']
resource_version_minor = node['resource']['version_minor']
resource_version_patch = node['resource']['version_patch']
resource_version_semantic = node['resource']['version_semantic']
ruby_block 'set_environment_version' do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    file.insert_line_if_no_match("RESOURCE_VERSION_MAJOR=#{resource_version_major}", "RESOURCE_VERSION_MAJOR=#{resource_version_major}")
    file.insert_line_if_no_match("RESOURCE_VERSION_MINOR=#{resource_version_minor}", "RESOURCE_VERSION_MINOR=#{resource_version_minor}")
    file.insert_line_if_no_match("RESOURCE_VERSION_PATCH=#{resource_version_patch}", "RESOURCE_VERSION_PATCH=#{resource_version_patch}")
    file.insert_line_if_no_match("RESOURCE_VERSION_SEMANTIC=#{resource_version_semantic}", "RESOURCE_VERSION_SEMANTIC=#{resource_version_semantic}")
    file.write_file
  end
end
