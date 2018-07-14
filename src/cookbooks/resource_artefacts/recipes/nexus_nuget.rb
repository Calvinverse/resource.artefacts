# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_nuget
#
# Copyright 2017, P. van der Velde
#

#
# CONFIGURE THE FILE SYSTEM
#

store_path = node['nexus3']['blob_store_path']
scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']

nuget_blob_store_path = "#{store_path}/nuget"
directory nuget_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '777'
  owner node['nexus3']['service_user']
end

#
# ADD THE NUGET REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_nuget_production_write = 'nuget_production_write'
nexus3_api 'nuget-production-write-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_production_write}', '#{nuget_blob_store_path}/#{blob_name_nuget_production_write}')"
  action %i[create run delete]
end

# create and run nuget hosted, proxy and group repositories
repository_name_nuget_production_write = 'nuget-production-write'
nexus3_api 'nuget-production-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('#{repository_name_nuget_production_write}', '#{blob_name_nuget_production_write}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_nuget_mirror = 'nuget_mirror'
nexus3_api 'nuget-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_mirror}', '#{scratch_blob_store_path}/#{blob_name_nuget_mirror}')"
  action %i[create run delete]
end

repository_name_nuget_proxy = 'nuget-proxy'
nexus3_api 'nuget-mirror' do
  content "repository.createNugetProxy('#{repository_name_nuget_proxy}','https://www.nuget.org/api/v2/', '#{blob_name_nuget_mirror}', true)"
  action %i[create run delete]
end

blob_name_nuget_production_group = 'nuget_production_group'
nexus3_api 'nuget-production-group-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_production_group}', '#{scratch_blob_store_path}/#{blob_name_nuget_production_group}')"
  action %i[create run delete]
end

repository_name_nuget_production_group = 'nuget-production-read'
nexus3_api 'nuget-production-read' do
  content "repository.createNugetGroup('#{repository_name_nuget_production_group}', ['#{repository_name_nuget_production_write}', '#{repository_name_nuget_proxy}'], '#{blob_name_nuget_production_group}')"
  action %i[create run delete]
end

# enable the NuGet API-key realm
nexus3_api 'nuget-api-key' do
  content 'import org.sonatype.nexus.security.realm.RealmManager;' \
  'realmManager = container.lookup(RealmManager.class.getName());' \
  "realmManager.enableRealm('NuGetApiKey', true);"
  action %i[create run delete]
end

#
# CONNECT TO CONSUL
#

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']

%i[read write].each do |repo_mode|
  file "/etc/consul/conf.d/nexus-nuget-production-#{repo_mode}.json" do
    action :create
    content <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_nuget_production_#{repo_mode}_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NuGet Production #{repo_mode} repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_nuget_production_#{repo_mode}_api",
            "name": "artefacts",
            "port": #{nexus_management_port},
            "tags": [
              "#{repo_mode}-production-nuget"
            ]
          }
        ]
      }
    JSON
  end
end

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the build system for pulling nuget packages
nexus3_api 'role-builds-pull-nuget' do
  content "security.addRole('nx-builds-pull-nuget', 'nx-builds-pull-nuget'," \
    " 'User with privileges to allow pulling packages from the different nuget repositories'," \
    " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing nuget packages
nexus3_api 'role-builds-push-nuget' do
  content "security.addRole('nx-builds-push-nuget', 'nx-builds-push-nuget'," \
    " 'User with privileges to allow pushing packages to the different nuget repositories'," \
    " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read', 'nx-repository-view-nuget-*-add', 'nx-repository-view-nuget-*-edit'], [''])"
  action :run
end

# Create the role which is used by the developers to read nuget repositories
nexus3_api 'role-developer-nuget' do
  content "security.addRole('nx-developer-nuget', 'nx-developer-nuget'," \
    " 'User with privileges to allow pulling packages from the nuget repositories'," \
    " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
  action :run
end
