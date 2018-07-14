# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_artefacts
#
# Copyright 2017, P. van der Velde
#

store_path = node['nexus3']['blob_store_path']

artefact_blob_store_path = "#{store_path}/artefacts"
directory artefact_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '777'
  owner node['nexus3']['service_user']
end

#
# ADD THE ARTEFACT REPOSITORIES
#
# see:

blob_name_artefacts_production = 'artefacts_production'
nexus3_api 'artefacts-production-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_artefacts_production}', '#{artefact_blob_store_path}/#{blob_name_artefacts_production}')"
  action %i[create run delete]
end

repository_name_artefacts_production = 'artefacts-production'
nexus3_api 'artefacts-production-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createRawHosted('#{repository_name_artefacts_production}', '#{blob_name_artefacts_production}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_artefacts_qa = 'artefacts_qa'
nexus3_api 'artefacts-qa-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_artefacts_qa}', '#{artefact_blob_store_path}/#{blob_name_artefacts_qa}')"
  action %i[create run delete]
end

repository_name_artefacts_qa = 'artefacts-qa'
nexus3_api 'artefacts-qa-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createRawHosted('#{repository_name_artefacts_qa}', '#{blob_name_artefacts_qa}', true, WritePolicy.ALLOW)"
  action %i[create run delete]
end

#
# CONNECT TO CONSUL
#

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file '/etc/consul/conf.d/nexus-artefacts-production.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_artefacts_production_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus artefacts production repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_artefacts_production_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-production",
            "write-production"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-artefacts-qa.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_artefacts_qa_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus artefacts QA repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_artefacts_qa_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-qa",
            "write-qa"
          ]
        }
      ]
    }
  JSON
end

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the build system for pulling artefacts
nexus3_api 'role-builds-pull-artefacts' do
  content "security.addRole('nx-builds-pull-artefacts', 'nx-builds-pull-artefacts'," \
    " 'User with privileges to allow pulling artefacts from the different repositories'," \
    " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing artefacts
nexus3_api 'role-builds-push-artefacts' do
  content "security.addRole('nx-builds-push-artefacts', 'nx-builds-push-artefacts'," \
    " 'User with privileges to allow pushing artefacts to the different repositories'," \
    " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read', 'nx-repository-view-raw-*-add', 'nx-repository-view-raw-*-edit'], [''])"
  action :run
end

# Create the role which is used by the developers to read artefact repositories
nexus3_api 'role-developer-artefacts' do
  content "security.addRole('nx-developer-artefacts', 'nx-developer-artefacts'," \
    " 'User with privileges to allow pulling artefacts'," \
    " ['nx-repository-view-raw-*-browse', 'nx-repository-view-raw-*-read'], [''])"
  action :run
end
