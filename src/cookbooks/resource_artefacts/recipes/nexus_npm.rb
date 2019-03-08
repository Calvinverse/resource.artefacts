# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_npm
#
# Copyright 2017, P. van der Velde
#

#
# CONFIGURE THE FILE SYSTEM
#

store_path = node['nexus3']['blob_store_path']
scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']

npm_blob_store_path = "#{store_path}/npm"
directory npm_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '770'
  owner node['nexus3']['service_user']
end

#
# ADD THE NPM REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_npm_hosted_production = 'npm_production_write'
nexus3_api 'npm-production-write-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_hosted_production}', '#{npm_blob_store_path}/#{blob_name_npm_hosted_production}')"
  action %i[create run delete]
end

repository_name_npm_production_write = 'npm-production-write'
nexus3_api 'npm-production-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('#{repository_name_npm_production_write}', '#{blob_name_npm_hosted_production}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_npm_mirror = 'npm_mirror'
nexus3_api 'npm-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_mirror}', '#{scratch_blob_store_path}/#{blob_name_npm_mirror}')"
  action %i[create run delete]
end

repository_name_npm_mirror = 'npm-proxy'
nexus3_api 'npm-mirror' do
  content "repository.createNpmProxy('#{repository_name_npm_mirror}','https://registry.npmjs.org/', '#{blob_name_npm_mirror}', true)"
  action %i[create run delete]
end

blob_name_npm_production_group = 'npm_production_group'
nexus3_api 'npm-production-group-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_production_group}', '#{scratch_blob_store_path}/#{blob_name_npm_production_group}')"
  action %i[create run delete]
end

repository_name_npm_production_read = 'npm-production-read'
nexus3_api 'npm-production-group' do
  content "repository.createNpmGroup('#{repository_name_npm_production_read}', ['#{repository_name_npm_production_write}', '#{repository_name_npm_mirror}'], '#{blob_name_npm_production_group}')"
  action %i[create run delete]
end

# enable the NPM Bearer Token realm
nexus3_api 'npm-bearer-token' do
  content 'import org.sonatype.nexus.security.realm.RealmManager;' \
  'realmManager = container.lookup(RealmManager.class.getName());' \
  "realmManager.enableRealm('NpmToken', true);"
  action %i[create run delete]
end

#
# CONNECT TO CONSUL
#

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']

%i[read write].each do |repo_mode|
  file "/etc/consul/conf.d/nexus-npm-production-#{repo_mode}.json" do
    action :create
    content <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
                "id": "nexus_npm_production_#{repo_mode}_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NPM Production #{repo_mode} repository ping",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "nexus_npm_production_#{repo_mode}_api",
            "name": "npm",
            "port": #{nexus_management_port},
            "tags": [
              "#{repo_mode}-production"
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

# Create the role which is used by the build system for pulling npm packages
nexus3_api 'role-builds-pull-npm' do
  content "security.addRole('nx-builds-pull-npm', 'nx-builds-pull-npm'," \
    " 'User with privileges to allow pulling packages from the different npm repositories'," \
    " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing nuget packages
nexus3_api 'role-builds-push-npm' do
  content "security.addRole('nx-builds-push-npm', 'nx-builds-push-npm'," \
    " 'User with privileges to allow pushing packages to the different npm repositories'," \
    " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read', 'nx-repository-view-npm-*-add', 'nx-repository-view-npm-*-edit'], [''])"
  action :run
end

# Create the role which is used by the developers to read npm repositories
nexus3_api 'role-developer-npm' do
  content "security.addRole('nx-developer-npm', 'nx-developer-npm'," \
    " 'User with privileges to allow pulling packages from the npm repositories'," \
    " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
  action :run
end
