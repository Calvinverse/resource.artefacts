# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_docker
#
# Copyright 2017, P. van der Velde
#

#
# CONFIGURE THE FILE SYSTEM
#

store_path = node['nexus3']['blob_store_path']
scratch_blob_store_path = node['nexus3']['scratch_blob_store_path']

docker_blob_store_path = "#{store_path}/docker"
directory docker_blob_store_path do
  action :create
  group node['nexus3']['service_group']
  mode '770'
  owner node['nexus3']['service_user']
end

#
# ADD THE DOCKER REPOSITORIES
#
# See: https://github.com/sonatype/nexus-public/blob/master/plugins/nexus-script-plugin/src/main/java/org/sonatype/nexus/script/plugin/RepositoryApi.java

blob_name_docker_hosted_production = 'docker_production_write'
nexus3_api 'docker-production-write-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted_production}', '#{docker_blob_store_path}/#{blob_name_docker_hosted_production}')"
  action %i[create run delete]
end

repository_name_docker_production_write = 'docker-production-write'
port_http_docker_hosted_production_write = node['nexus3']['repository']['docker']['port']['http']['production']['write']
port_https_docker_hosted_production_write = node['nexus3']['repository']['docker']['port']['https']['production']['write']
nexus3_api 'docker-production-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('#{repository_name_docker_production_write}', #{port_http_docker_hosted_production_write}, #{port_https_docker_hosted_production_write}, '#{blob_name_docker_hosted_production}', true, true, WritePolicy.ALLOW_ONCE)"
  action %i[create run delete]
end

blob_name_docker_hosted_qa = 'docker_qa_write'
nexus3_api 'docker-qa-write-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_hosted_qa}', '#{docker_blob_store_path}/#{blob_name_docker_hosted_qa}')"
  action %i[create run delete]
end

repository_name_docker_qa_write = 'docker-qa-write'
port_http_docker_hosted_qa_write = node['nexus3']['repository']['docker']['port']['http']['qa']['write']
port_https_docker_hosted_qa_write = node['nexus3']['repository']['docker']['port']['https']['qa']['write']
nexus3_api 'docker-qa-write' do
  content "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('#{repository_name_docker_qa_write}', #{port_http_docker_hosted_qa_write}, #{port_https_docker_hosted_qa_write}, '#{blob_name_docker_hosted_qa}', true, true, WritePolicy.ALLOW)"
  action %i[create run delete]
end

blob_name_docker_mirror = 'docker_mirror'
nexus3_api 'docker-mirror-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_mirror}', '#{scratch_blob_store_path}/#{blob_name_docker_mirror}')"
  action %i[create run delete]
end

# Set the docker-mirror to allow anonymous access, otherwise it won't mirror: https://issues.sonatype.org/browse/NEXUS-10813
repository_name_docker_mirror = 'docker-proxy'
port_http_docker_mirror = node['nexus3']['repository']['docker']['port']['http']['mirror']
port_https_docker_mirror = node['nexus3']['repository']['docker']['port']['https']['mirror']
groovy_docker_mirror_content = <<~GROOVY
  import org.sonatype.nexus.repository.config.Configuration;
  configuration = new Configuration(
      repositoryName: 'hub.docker.io',
      recipeName: '#{repository_name_docker_mirror}',
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

blob_name_docker_group_production = 'docker_production_group'
nexus3_api 'docker-production-read-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_group_production}', '#{scratch_blob_store_path}/#{blob_name_docker_group_production}')"
  action %i[create run delete]
end

port_http_docker_hosted_production_read = node['nexus3']['repository']['docker']['port']['http']['production']['read']
port_https_docker_hosted_production_read = node['nexus3']['repository']['docker']['port']['https']['production']['read']
nexus3_api 'docker-production-group' do
  content "repository.createDockerGroup('docker-production-read', #{port_http_docker_hosted_production_read}, #{port_https_docker_hosted_production_read}, ['#{repository_name_docker_production_write}', '#{repository_name_docker_mirror}'], true, '#{blob_name_docker_group_production}')"
  action %i[create run delete]
end

blob_name_docker_group_qa = 'docker_qa_group'
nexus3_api 'docker-qa-read-blob' do
  content "blobStore.createFileBlobStore('#{blob_name_docker_group_qa}', '#{scratch_blob_store_path}/#{blob_name_docker_group_qa}')"
  action %i[create run delete]
end

port_http_docker_hosted_qa_read = node['nexus3']['repository']['docker']['port']['http']['qa']['read']
port_https_docker_hosted_qa_read = node['nexus3']['repository']['docker']['port']['https']['qa']['read']
nexus3_api 'docker-qa-group' do
  content "repository.createDockerGroup('docker-qa-read', #{port_http_docker_hosted_qa_read}, #{port_https_docker_hosted_qa_read}, ['#{repository_name_docker_production_write}', '#{repository_name_docker_qa_write}', '#{repository_name_docker_mirror}'], true, '#{blob_name_docker_group_qa}')"
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
# ALLOW NEXUS THROUGH THE FIREWALL
#

firewall_rule 'nexus-docker-production-read-http' do
  command :allow
  description 'Allow Docker Production read HTTP traffic'
  dest_port port_http_docker_hosted_production_read
  direction :in
end

firewall_rule 'nexus-docker-production-write-http' do
  command :allow
  description 'Allow Docker Production write HTTP traffic'
  dest_port port_http_docker_hosted_production_write
  direction :in
end

firewall_rule 'nexus-docker-production-read-https' do
  command :allow
  description 'Allow Docker Production read HTTPs traffic'
  dest_port port_https_docker_hosted_production_read
  direction :in
end

firewall_rule 'nexus-docker-production-write-https' do
  command :allow
  description 'Allow Docker Production write HTTPs traffic'
  dest_port port_https_docker_hosted_production_write
  direction :in
end

firewall_rule 'nexus-docker-qa-read-http' do
  command :allow
  description 'Allow Docker QA read HTTP traffic'
  dest_port port_http_docker_hosted_qa_read
  direction :in
end

firewall_rule 'nexus-docker-qa-write-http' do
  command :allow
  description 'Allow Docker QA write HTTP traffic'
  dest_port port_http_docker_hosted_qa_write
  direction :in
end

firewall_rule 'nexus-docker-qa-read-https' do
  command :allow
  description 'Allow Docker QA read HTTPs traffic'
  dest_port port_https_docker_hosted_qa_read
  direction :in
end

firewall_rule 'nexus-docker-qa-write-https' do
  command :allow
  description 'Allow Docker QA write HTTPs traffic'
  dest_port port_https_docker_hosted_qa_write
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

nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file '/etc/consul/conf.d/nexus-docker-production-read.json' do # ~FC005
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_production_read_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker Production read repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_docker_production_read_api",
          "name": "docker",
          "port": #{port_http_docker_hosted_production_read},
          "tags": [
            "read-production"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-production-write.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_production_write_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker Production write repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_docker_production_write_api",
          "name": "docker",
          "port": #{port_http_docker_hosted_production_write},
          "tags": [
            "write-production"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-qa-read.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_qa_read_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker QA read repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_docker_qa_read_api",
          "name": "docker",
          "port": #{port_http_docker_hosted_qa_read},
          "tags": [
            "read-qa"
          ]
        }
      ]
    }
  JSON
end

file '/etc/consul/conf.d/nexus-docker-qa-write.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
              "http": "http://localhost:#{nexus_management_port}#{nexus_proxy_path}/service/metrics/ping",
              "id": "nexus_docker_qa_write_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus Docker QA write repository ping",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "nexus_docker_qa_write_api",
          "name": "docker",
          "port": #{port_http_docker_hosted_qa_write},
          "tags": [
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

# Create the role which is used by the infrastructure for pulling docker containers
nexus3_api 'role-docker-pull' do
  content "security.addRole('nx-infrastructure-container-pull', 'nx-infrastructure-container-pull'," \
    " 'User with privileges to allow pulling containers from the different container repositories'," \
    " ['nx-repository-view-docker-docker-production-browse', 'nx-repository-view-docker-docker-production-read'], [''])"
  action :run
end

nexus3_api 'userNomad' do
  action :run
  content "security.addUser('container.pull', 'Container', 'Pull', 'container.pull@vista.co', true, 'container.pull', ['nx-infrastructure-container-pull'])"
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

# Create the role which is used by the developers to read docker repositories
nexus3_api 'role-developer-docker' do
  content "security.addRole('nx-developer-docker', 'nx-developer-docker'," \
    " 'User with privileges to allow pulling containers from the docker repositories'," \
    " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
  action :run
end
