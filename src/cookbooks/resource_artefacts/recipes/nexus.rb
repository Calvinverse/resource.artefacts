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
# CONFIGURE THE FILE SYSTEM
#

store_path = '/srv/nexus/blob'
directory store_path do
  action :create
  recursive true
end

scratch_blob_store_path = "#{store_path}/scratch"
directory scratch_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

docker_blob_store_path = "#{store_path}/docker"
directory docker_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

npm_blob_store_path = "#{store_path}/npm"
directory npm_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

nuget_blob_store_path = "#{store_path}/nuget"
directory nuget_blob_store_path do
  action :create
  group node['nexus']['service_group']
  mode '777'
  owner node['nexus']['service_user']
end

#
# INSTALL NEXUS
#

nexus3 'nexus' do
  action :install
  group node['nexus']['service_group']
  user node['nexus']['service_user']
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
# ADD THE DOCKER REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_docker_hosted_production = 'docker_production'
nexus3_api 'docker-production-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted_production}', '#{docker_blob_store_path}/#{blob_name_docker_hosted_production}')"
  action %i[create run delete]
end

port_http_docker_hosted_production = node['nexus3']['repository']['docker']['port']['http']['production']
port_https_docker_hosted_production = node['nexus3']['repository']['docker']['port']['https']['production']
nexus3_api 'docker-production' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-production', #{port_http_docker_hosted_production}, #{port_https_docker_hosted_production}, '#{blob_name_docker_hosted_production}', true, true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_docker_hosted_qa = 'docker_qa'
nexus3_api 'docker-qa-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted_qa}', '#{docker_blob_store_path}/#{blob_name_docker_hosted_qa}')"
  action %i[create run delete]
end

port_http_docker_hosted_qa = node['nexus3']['repository']['docker']['port']['http']['qa']
port_https_docker_hosted_qa = node['nexus3']['repository']['docker']['port']['https']['qa']
nexus3_api 'docker-qa' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-qa', #{port_http_docker_hosted_qa}, #{port_https_docker_hosted_qa}, '#{blob_name_docker_hosted_qa}', true, true, WritePolicy.ALLOW)"
  action %i[create run delete]
end

blob_name_docker_mirror = 'docker_mirror'
nexus3_api 'docker-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_mirror}', '#{scratch_blob_store_path}/#{blob_name_docker_mirror}')"
  action %i[create run delete]
end

# Set the docker-mirror to allow anonymous access, otherwise it won't mirror: https://issues.sonatype.org/browse/NEXUS-10813
port_http_docker_mirror = node['nexus3']['repository']['docker']['port']['http']['mirror']
port_https_docker_mirror = node['nexus3']['repository']['docker']['port']['https']['mirror']
groovy_docker_mirror_content = <<~GROOVY
  import org.sonatype.nexus.repository.config.Configuration;
  configuration = new Configuration(
      repositoryName: 'hub.docker.io',
      recipeName: 'docker-proxy',
      online: true,
      attributes: [
          docker: [
              forceBasicAuth: false,
              httpPort: #{port_http_docker_mirror},
              httpsPort: #{port_https_docker_mirror},
              v1Enabled: true
          ],
          proxy: [
              remoteUrl: 'https://registry-1.docker.io'
          ],
          dockerProxy: [
              indexType: 'HUB'
          ],
          storage: [
              writePolicy: 'ALLOW_ONCE',
              blobStoreName: '#{blob_name_docker_mirror}',
              strictContentTypeValidation: true
          ]
      ]
  );

  repository.getRepositoryManager().create(configuration);
GROOVY
nexus3_api 'docker-mirror' do
  content groovy_docker_mirror_content
  action %i[create run delete]
end

# enable the Docker Bearer Token realm
nexus3_api 'docker-bearer-token' do
  content 'import org.sonatype.nexus.security.realm.RealmManager;' \
  'realmManager = container.lookup(RealmManager.class.getName());' \
  "realmManager.enableRealm('DockerToken', true);"
  action %i[create run delete]
end

#
# ADD THE NPM REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_npm_hosted_production = 'npm_production'
nexus3_api 'npm-production-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_hosted_production}', '#{npm_blob_store_path}/#{blob_name_npm_hosted_production}')"
  action %i[create run delete]
end

nexus3_api 'npm-production' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-production', '#{blob_name_npm_hosted_production}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_npm_hosted_qa = 'npm_qa'
nexus3_api 'npm-qa-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_hosted_qa}', '#{npm_blob_store_path}/#{blob_name_npm_hosted_qa}')"
  action %i[create run delete]
end

nexus3_api 'npm-qa' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-qa', '#{blob_name_npm_hosted_qa}', true, WritePolicy.ALLOW)"
  action %i[create run delete]
end

blob_name_npm_mirror = 'npm_mirror'
nexus3_api 'npm-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_npm_mirror}', '#{scratch_blob_store_path}/#{blob_name_npm_mirror}')"
  action %i[create run delete]
end

nexus3_api 'npm-mirror' do
  content "repository.createNpmProxy('npmjs.org','https://www.npmjs.org/', '#{blob_name_npm_mirror}', true)"
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
# ADD THE NUGET REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_nuget_hosted = 'nuget_hosted'
nexus3_api 'nuget-hosted-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_hosted}', '#{nuget_blob_store_path}/#{blob_name_nuget_hosted}')"
  action %i[create run delete]
end

# create and run rubygems hosted, proxy and group repositories
nexus3_api 'nuget-hosted' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('nuget', '#{blob_name_nuget_hosted}', true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_nuget_mirror = 'nuget_mirror'
nexus3_api 'nuget-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_nuget_mirror}', '#{scratch_blob_store_path}/#{blob_name_nuget_mirror}')"
  action %i[create run delete]
end

nexus3_api 'nuget-mirror' do
  content "repository.createNugetProxy('nuget.org','https://www.nuget.org/api/v2/', '#{blob_name_nuget_mirror}', true)"
  action %i[create run delete]
end

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
# ALLOW NEXUS THROUGH THE FIREWALL
#

nexus_management_port = node['nexus3']['port']
firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port nexus_management_port
  direction :in
end

firewall_rule 'nexus-docker-production-http' do
  command :allow
  description 'Allow Docker HTTP traffic'
  dest_port port_http_docker_hosted_production
  direction :in
end

firewall_rule 'nexus-docker-production-https' do
  command :allow
  description 'Allow Docker HTTPs traffic'
  dest_port port_https_docker_hosted_production
  direction :in
end

firewall_rule 'nexus-docker-qa-http' do
  command :allow
  description 'Allow Docker HTTP traffic'
  dest_port port_http_docker_hosted_qa
  direction :in
end

firewall_rule 'nexus-docker-qa-https' do
  command :allow
  description 'Allow Docker HTTPs traffic'
  dest_port port_https_docker_hosted_qa
  direction :in
end

firewall_rule 'nexus-docker-mirror-http' do
  command :allow
  description 'Allow Docker HTTP traffic'
  dest_port port_http_docker_mirror
  direction :in
end

firewall_rule 'nexus-docker-mirror-https' do
  command :allow
  description 'Allow Docker HTTPs traffic'
  dest_port port_https_docker_mirror
  direction :in
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

file '/etc/consul/conf.d/nexus-docker-production.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_production_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker production repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_docker_production_api",
          "name": "artefacts",
          "port": #{port_http_docker_hosted_production},
          "tags": [
            "read-production-docker",
            "write-production-docker"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-qa.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_qa_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker QA repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_docker_qa_api",
          "name": "artefacts",
          "port": #{port_http_docker_hosted_qa},
          "tags": [
            "read-qa-docker",
            "write-qa-docker"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker mirror repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_docker_mirror_api",
          "name": "artefacts",
          "port": #{port_http_docker_mirror},
          "tags": [
            "read-mirror-docker"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-npm-production.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_npm_production_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NPM production repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_npm_production_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-production-npm",
            "write-production-npm"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-npm-qa.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_npm_qa_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NPM QA repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_npm_qa_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-qa-npm",
            "write-qa-npm"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-npm-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_npm_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NPM mirror repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_npm_mirror_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-mirror-npm"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-nuget-production.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_nuget_production_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NuGet production repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_nuget_production_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-production-nuget",
            "write-production-nuget"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-nuget-mirror.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_nuget_mirror_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus NuGet mirror repository ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": true,
          "id": "nexus_nuget_mirror_api",
          "name": "artefacts",
          "port": #{nexus_management_port},
          "tags": [
            "read-mirror-nuget"
          ]
        }
      ]
    }
  JSON
end

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
          "enableTagOverride": true,
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

# Create the role which is used by the infrastructure for pulling docker containers
nexus3_api 'role-docker-pull' do
  content "security.addRole('nx-infrastructure-container-pull', 'nx-infrastructure-container-pull'," \
    " 'User with privileges to allow pulling containers from the different container repositories'," \
    " ['nx-repository-view-docker-production-browse', 'nx-repository-view-docker-production-read'], [''])"
  action :run
end

nexus3_api 'userNomad' do
  action :run
  content "security.addUser('nomad.container.pull', 'Nomad', 'Container.Pull', 'nomad.container.pull@example.com', true, 'nomad.container.pull', ['nx-infrastructure-container-pull'])"
end

# Create the role which is used by the build system for pulling docker containers
nexus3_api 'role-builds-pull-containers' do
  content "security.addRole('nx-builds-pull-containers', 'nx-builds-pull-containers'," \
    " 'User with privileges to allow pulling containers from the different container repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
  action :run
end

# Create the role which is used by the build system for pushing docker containers
nexus3_api 'role-builds-push-containers' do
  content "security.addRole('nx-builds-push-containers', 'nx-builds-push-containers'," \
    " 'User with privileges to allow pushing containers to the different container repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read', 'nx-repository-view-docker-*-add', 'nx-repository-view-docker-*-edit'], [''])"
  action :run
end

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

# Create the role which is used by the build system for pulling ruby gems packages
nexus3_api 'role-builds-pull-rubygems' do
  content "security.addRole('nx-builds-pull-rubygems', 'nx-builds-pull-rubygems'," \
    " 'User with privileges to allow pulling packages from the different rubygems repositories'," \
    " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read docker repositories
nexus3_api 'role-developer-docker' do
  content "security.addRole('nx-developer-docker', 'nx-developer-docker'," \
    " 'User with privileges to allow pulling containers from the docker repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read npm repositories
nexus3_api 'role-developer-npm' do
  content "security.addRole('nx-developer-npm', 'nx-developer-npm'," \
    " 'User with privileges to allow pulling packages from the npm repositories'," \
    " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read nuget repositories
nexus3_api 'role-developer-nuget' do
  content "security.addRole('nx-developer-nuget', 'nx-developer-nuget'," \
    " 'User with privileges to allow pulling packages from the nuget repositories'," \
    " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
  action :run
end

# Create the role which is used by the developers to read gems repositories
nexus3_api 'role-developer-rubygems' do
  content "security.addRole('nx-developer-rubygems', 'nx-developer-rubygems'," \
    " 'User with privileges to allow pulling packages from the ruby gems repositories'," \
    " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
  action :run
end

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
    user node['nexus']['service_user']
  end
end

#
# SET THE PROXY PATH
#

nexus_data_path = node['nexus3']['data']
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
