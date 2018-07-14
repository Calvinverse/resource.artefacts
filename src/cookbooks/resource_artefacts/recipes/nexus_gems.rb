# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_gems
#
# Copyright 2017, P. van der Velde
#

#
# CONFIGURE THE FILE SYSTEM
#

scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']

#
# ADD THE RUBY GEM REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_gems_mirror = 'gems_mirror'
nexus3_api 'gems-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_gems_mirror}', '#{scratch_blob_store_path}/#{blob_name_gems_mirror}')"
  action %i[create run delete]
end

nexus3_api 'gems-mirror' do
  content "repository.createRubygemsProxy('rubygems.org','https://rubygems.org', '#{blob_name_gems_mirror}', true)"
  action %i[create run delete]
end

#
# CONNECT TO CONSUL
#

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file '/etc/consul/conf.d/nexus-gems-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_gems_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Ruby Gems mirror repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_gems_mirror_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-mirror-gems"
          ]
        }
      ]
    }
  JSON
end

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the build system for pulling ruby gems packages
nexus3_api 'role-builds-pull-rubygems' do
  content "security.addRole('nx-builds-pull-rubygems', 'nx-builds-pull-rubygems'," \
    " 'User with privileges to allow pulling packages from the different rubygems repositories'," \
    " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read gems repositories
nexus3_api 'role-developer-rubygems' do
  content "security.addRole('nx-developer-rubygems', 'nx-developer-rubygems'," \
    " 'User with privileges to allow pulling packages from the ruby gems repositories'," \
    " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
  action :run
end
