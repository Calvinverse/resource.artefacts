# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_artefacts::nexus_docker' do
  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_docker file system at /srv/nexus/blob/docker' do
      expect(chef_run).to create_directory('/srv/nexus/blob/docker').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'creates docker repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for production write docker images' do
      expect(chef_run).to run_nexus3_api('docker-production-write-blob').with(
        content: "blobStore.createFileBlobStore('docker_production_write', '/srv/nexus/blob/docker/docker_production_write')"
      )
    end

    it 'creates a repository for production write docker images' do
      expect(chef_run).to run_nexus3_api('docker-production-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-production-write', 5002, 5003, 'docker_production_write', true, true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for qa write docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa-write-blob').with(
        content: "blobStore.createFileBlobStore('docker_qa_write', '/srv/nexus/blob/docker/docker_qa_write')"
      )
    end

    it 'creates a repository for qa write docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa-write').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-qa-write', 5012, 5013, 'docker_qa_write', true, true, WritePolicy.ALLOW)"
      )
    end

    it 'creates a blob store for mirrored docker images' do
      expect(chef_run).to run_nexus3_api('docker-mirror-blob').with(
        content: "blobStore.createFileBlobStore('docker_mirror', '/srv/nexus/blob/scratch/docker_mirror')"
      )
    end

    groovy_docker_mirror_content = <<~GROOVY
      import org.sonatype.nexus.repository.config.Configuration;
      configuration = new Configuration(
          repositoryName: 'hub.docker.io',
          recipeName: 'docker-proxy',
          online: true,
          attributes: [
              docker: [
                  forceBasicAuth: false,
                  httpPort: 5020,
                  httpsPort: 5021,
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
                  blobStoreName: 'docker_mirror',
                  strictContentTypeValidation: true
              ]
          ]
      );

      repository.getRepositoryManager().create(configuration);
    GROOVY
    it 'creates a repository for mirror docker images' do
      expect(chef_run).to run_nexus3_api('docker-mirror').with(
        content: groovy_docker_mirror_content
      )
    end

    it 'creates a blob store for production read docker images' do
      expect(chef_run).to run_nexus3_api('docker-production-read-blob').with(
        content: "blobStore.createFileBlobStore('docker_production_group', '/srv/nexus/blob/scratch/docker_production_group')"
      )
    end

    it 'creates a repository for production docker images' do
      expect(chef_run).to run_nexus3_api('docker-production-read').with(
        content: "repository.createDockerGroup('docker-production-read', 5000, 5001, ['docker-production-write', 'docker-proxy'], true, 'docker_production_group')"
      )
    end

    it 'creates a blob store for qa read docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa-read-blob').with(
        content: "blobStore.createFileBlobStore('docker_qa_group', '/srv/nexus/blob/scratch/docker_qa_group')"
      )
    end

    it 'creates a repository for qa docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa-read').with(
        content: "repository.createDockerGroup('docker-qa-read', 5010, 5011, ['docker-production-write', 'docker-qa-write', 'docker-proxy'], true, 'docker_qa_group')"
      )
    end

    it 'enables the docker bearer token realm' do
      expect(chef_run).to run_nexus3_api('docker-bearer-token').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('DockerToken', true);"
      )
    end
  end

  context 'configures the firewall for nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Docker production read repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-read-http').with(
        command: :allow,
        dest_port: 5000,
        direction: :in
      )
    end

    it 'opens the Docker production read repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-read-https').with(
        command: :allow,
        dest_port: 5001,
        direction: :in
      )
    end

    it 'opens the Docker production write repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-write-http').with(
        command: :allow,
        dest_port: 5002,
        direction: :in
      )
    end

    it 'opens the Docker production write repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-write-https').with(
        command: :allow,
        dest_port: 5003,
        direction: :in
      )
    end

    it 'opens the Docker qa read repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-read-http').with(
        command: :allow,
        dest_port: 5010,
        direction: :in
      )
    end

    it 'opens the Docker qa read repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-read-https').with(
        command: :allow,
        dest_port: 5011,
        direction: :in
      )
    end

    it 'opens the Docker qa write repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-write-http').with(
        command: :allow,
        dest_port: 5012,
        direction: :in
      )
    end

    it 'opens the Docker qa write repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-write-https').with(
        command: :allow,
        dest_port: 5013,
        direction: :in
      )
    end

    it 'opens the Docker mirror repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-mirror-http').with(
        command: :allow,
        dest_port: 5020,
        direction: :in
      )
    end

    it 'opens the Docker mirror repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-mirror-https').with(
        command: :allow,
        dest_port: 5021,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_nexus_docker_production_read_config_content = <<~JSON
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
                "name": "Nexus Docker production read repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_docker_production_read_api",
            "name": "artefacts",
            "port": 5000,
            "tags": [
              "read-production-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-production-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-production-read.json')
        .with_content(consul_nexus_docker_production_read_config_content)
    end

    consul_nexus_docker_production_write_config_content = <<~JSON
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
                "name": "Nexus Docker production write repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": false,
            "id": "nexus_docker_production_write_api",
            "name": "artefacts",
            "port": 5002,
            "tags": [
              "write-production-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-production-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-production-write.json')
        .with_content(consul_nexus_docker_production_write_config_content)
    end

    consul_nexus_docker_qa_read_config_content = <<~JSON
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
            "enableTagOverride": false,
            "id": "nexus_docker_qa_read_api",
            "name": "artefacts",
            "port": 5010,
            "tags": [
              "read-qa-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-qa-read.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-qa-read.json')
        .with_content(consul_nexus_docker_qa_read_config_content)
    end

    consul_nexus_docker_qa_write_config_content = <<~JSON
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
            "enableTagOverride": false,
            "id": "nexus_docker_qa_write_api",
            "name": "artefacts",
            "port": 5012,
            "tags": [
              "write-qa-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-qa-write.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-qa-write.json')
        .with_content(consul_nexus_docker_qa_write_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-infrastructure-container-pull role' do
      expect(chef_run).to run_nexus3_api('role-docker-pull').with(
        content: "security.addRole('nx-infrastructure-container-pull', 'nx-infrastructure-container-pull'," \
        " 'User with privileges to allow pulling containers from the different container repositories'," \
        " ['nx-repository-view-docker-docker-production-browse', 'nx-repository-view-docker-docker-production-read'], [''])"
      )
    end

    it 'create a nomad user' do
      expect(chef_run).to run_nexus3_api('userNomad').with(
        content: "security.addUser('nomad.container.pull', 'Nomad', 'Container.Pull', 'nomad.container.pull@example.com', true, 'nomad.container.pull', ['nx-infrastructure-container-pull'])"
      )
    end

    it 'create a nx-builds-pull-containers role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-containers').with(
        content: "security.addRole('nx-builds-pull-containers', 'nx-builds-pull-containers'," \
        " 'User with privileges to allow pulling containers from the different container repositories'," \
        " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-containers role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-containers').with(
        content: "security.addRole('nx-builds-push-containers', 'nx-builds-push-containers'," \
        " 'User with privileges to allow pushing containers to the different container repositories'," \
        " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read', 'nx-repository-view-docker-*-add', 'nx-repository-view-docker-*-edit'], [''])"
      )
    end

    it 'create a nx-developer-docker role' do
      expect(chef_run).to run_nexus3_api('role-developer-docker').with(
        content: "security.addRole('nx-developer-docker', 'nx-developer-docker'," \
        " 'User with privileges to allow pulling containers from the docker repositories'," \
        " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
      )
    end
  end
end
