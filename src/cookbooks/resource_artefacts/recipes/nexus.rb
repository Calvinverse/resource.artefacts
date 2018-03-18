# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['nexus3']['service_user'] do
  group node['nexus3']['service_group']
end

#
# CONFIGURE THE FILE SYSTEM
#

store_path = node['nexus3']['blob_store_path']
directory store_path do
  action :create
  recursive true
end

scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']
directory scratch_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '777'
  owner node['nexus3']['service_user']
end

#
# ALLOW NEXUS THROUGH THE FIREWALL
#

# do this before installing nexus because all the api commands in this cookbook hit the nexus3 HTTP endpoint
# and if the firewall is blocking the port ...
nexus_management_port = node['nexus3']['port']
firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port nexus_management_port
  direction :in
end

# Force the firewall settings so that we can actually communicate with nexus
firewall 'default' do
  action :restart
end

#
# INSTALL NEXUS
#

nexus_instance_name = node['nexus3']['instance_name']
nexus3 nexus_instance_name do
  action :install
  group node['nexus3']['service_group']
  user node['nexus3']['service_user']
end

#
# DELETE THE DEFAULT REPOSITORIES
#

%w[maven-central maven-public maven-releases maven-snapshots nuget-group nuget-hosted nuget.org-proxy].each do |repo|
  nexus3_api "delete_repo #{repo}" do
    action %i[create run delete]
    script_name "delete_repo_#{repo}"
    content "repository.repositoryManager.delete('#{repo}')"
  end
end

nexus3_api 'delete_default_blobstore' do
  action %i[create run delete]
  script_name 'delete_default_blobstore'
  content "blobStore.blobStoreManager.delete('default')"
end

#
# ENABLE LDAP TOKEN REALM
#

nexus3_api 'ldap-realm' do
  content 'import org.sonatype.nexus.security.realm.RealmManager;' \
  'realmManager = container.lookup(RealmManager.class.getName());' \
  "realmManager.enableRealm('LdapRealm', true);"
  action %i[create run delete]
end

#
# CONNECT TO CONSUL
#

# Create the user which is used by consul for the health check
nexus3_api 'role-metrics' do
  content "security.addRole('nx-metrics', 'nx-metrics'," \
    " 'User with privileges to allow read access to the Nexus metrics'," \
    " ['nx-metrics-all'], ['nx-anonymous'])"
  action :run
end

nexus3_api 'userConsul' do
  action :run
  content "security.addUser('consul.health', 'Consul', 'Health', 'consul.health@example.com', true, 'consul.health', ['nx-metrics'])"
end

nexus_proxy_path = node['nexus3']['proxy_path']
file '/etc/consul/conf.d/nexus-management.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_management_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus management ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_management",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "edgeproxyprefix-#{nexus_proxy_path}",
            "management",
            "active-management"
          ]
        }
      ]
    }
  JSON
end

#
# CREATE ADDITIONAL ROLES AND USERS
#

# Create the role which is used by the developers to search repositories
nexus3_api 'role-developer-search' do
  content "security.addRole('nx-developer-search', 'nx-developer-search'," \
    " 'User with privileges to allow searching for packages in the different repositories'," \
    " ['nx-search-read', 'nx-selectors-read'], [''])"
  action :run
end

#
# DISABLE ANONYMOUS ACCESS
#

nexus3_api 'anonymous' do
  action :run
  content 'security.setAnonymousAccess(false)'
  not_if { ::File.exist?("#{node['nexus3']['data']}/tmp") }
end
