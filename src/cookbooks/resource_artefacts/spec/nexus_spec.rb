# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus' do
  context 'creates the nexus user' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
  end

  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_scratch file system at /srv/nexus/blob/scratch' do
      expect(chef_run).to create_directory('/srv/nexus/blob/scratch').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end

    it 'creates and mounts the nexus_docker file system at /srv/nexus/blob/docker' do
      expect(chef_run).to create_directory('/srv/nexus/blob/docker').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end

    it 'creates and mounts the nexus_nuget file system at /srv/nexus/blob/nuget' do
      expect(chef_run).to create_directory('/srv/nexus/blob/nuget').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end

  context 'configures nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs nexus' do
      expect(chef_run).to install_nexus3('nexus')
    end

    it 'disables anonymous access' do
      expect(chef_run).to run_nexus3_api('anonymous').with(
        content: 'security.setAnonymousAccess(false)'
      )
    end

    it 'deletes the maven-central repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-central')
    end

    it 'deletes the maven-public repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-public')
    end

    it 'deletes the maven-releases repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-releases')
    end

    it 'deletes the maven-snapshots repository' do
      expect(chef_run).to run_nexus3_api('delete_repo maven-snapshots')
    end

    it 'deletes the nuget-group repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget-group')
    end

    it 'deletes the nuget-hosted repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget-hosted')
    end

    it 'deletes the nuget.org-proxy repository' do
      expect(chef_run).to run_nexus3_api('delete_repo nuget.org-proxy')
    end

    it 'deletes the default blob store' do
      expect(chef_run).to run_nexus3_api('delete_default_blobstore')
    end
  end

  context 'creates docker repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for hosted docker images' do
      expect(chef_run).to run_nexus3_api('docker-hosted-blob').with(
        content: "blobStore.createFileBlobStore('docker_hosted', '/srv/nexus/blob/docker/docker_hosted')"
      )
    end

    it 'creates a repository for hosted docker images' do
      expect(chef_run).to run_nexus3_api('docker-hosted').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker', 5000, 5001, 'docker_hosted', true, true, WritePolicy.ALLOW)"
      )
    end

    it 'creates a blob store for mirrored docker images' do
      expect(chef_run).to run_nexus3_api('docker-mirror-blob').with(
        content: "blobStore.createFileBlobStore('docker_mirror', '/srv/nexus/blob/scratch/docker_mirror')"
      )
    end

    it 'creates a repository for mirror docker images' do
      expect(chef_run).to run_nexus3_api('docker-mirror').with(
        content: "repository.createDockerProxy('hub.docker.io','https://registry-1.docker.io', 'HUB', '', 5010, 5011, 'docker_mirror', true, true)"
      )
    end
  end

  context 'creates nuget repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for hosted nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-hosted-blob').with(
        content: "blobStore.createFileBlobStore('nuget_hosted', '/srv/nexus/blob/nuget/nuget_hosted')"
      )
    end

    it 'creates a repository for hosted nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-hosted').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNugetHosted('nuget', 'nuget_hosted', true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for mirrored nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-mirror-blob').with(
        content: "blobStore.createFileBlobStore('nuget_mirror', '/srv/nexus/blob/scratch/nuget_mirror')"
      )
    end

    it 'creates a repository for mirror nuget packages' do
      expect(chef_run).to run_nexus3_api('nuget-mirror').with(
        content: "repository.createNugetProxy('nuget.org','https://www.nuget.org/api/v2/', 'nuget_mirror', true)"
      )
    end
  end

  context 'configures the firewall for nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Nexus HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-http').with(
        command: :allow,
        dest_port: 8081,
        direction: :in
      )
    end

    it 'opens the Docker hosted repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-hosted-http').with(
        command: :allow,
        dest_port: 5000,
        direction: :in
      )
    end

    it 'opens the Docker hosted repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-hosted-https').with(
        command: :allow,
        dest_port: 5001,
        direction: :in
      )
    end

    it 'opens the Docker mirror repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-mirror-http').with(
        command: :allow,
        dest_port: 5010,
        direction: :in
      )
    end

    it 'opens the Docker mirror repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-mirror-https').with(
        command: :allow,
        dest_port: 5011,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nexus metrics role' do
      expect(chef_run).to run_nexus3_api('role-metrics').with(
        content: "security.addRole('nx-metrics', 'nx-metrics', 'User with privileges to allow read access to the Nexus metrics', ['nx-metrics-all'], ['nx-anonymous'])"
      )
    end

    it 'create a consul user' do
      expect(chef_run).to run_nexus3_api('userConsul').with(
        content: "security.addUser('consul.health', 'Consul', 'Health', 'consul.health@example.com', true, 'consul.health', ['nx-metrics'])"
      )
    end

    consul_nexus_management_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:8081/service/metrics/ping",
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
            "port": 8081,
            "tags": [
              "edgeproxyprefix-/artefacts",
              "management",
              "active-management"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-management.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-management.json')
        .with_content(consul_nexus_management_config_content)
    end

    consul_nexus_docker_hosted_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:8081/service/metrics/ping",
                "id": "nexus_docker_hosted_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus Docker hosted repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": true,
            "id": "nexus_docker_hosted_api",
            "name": "artefacts",
            "port": 5000,
            "tags": [
              "read-hosted-docker",
              "write-hosted-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-hosted.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-hosted.json')
        .with_content(consul_nexus_docker_hosted_config_content)
    end

    consul_nexus_docker_mirror_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:8081/service/metrics/ping",
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
            "port": 5010,
            "tags": [
              "read-mirror-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-mirror.json')
        .with_content(consul_nexus_docker_mirror_config_content)
    end

    consul_nexus_nuget_hosted_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:8081/service/metrics/ping",
                "id": "nexus_nuget_hosted_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NuGet hosted repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": true,
            "id": "nexus_nuget_hosted_api",
            "name": "artefacts",
            "port": 8081,
            "tags": [
              "read-hosted-nuget",
              "write-hosted-nuget"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-nuget-hosted.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-hosted.json')
        .with_content(consul_nexus_nuget_hosted_config_content)
    end

    consul_nexus_nuget_mirror_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "header": { "Authorization" : ["Basic Y29uc3VsLmhlYWx0aDpjb25zdWwuaGVhbHRo"]},
                "http": "http://localhost:8081/service/metrics/ping",
                "id": "nexus_nuget_mirror_api_ping",
                "interval": "15s",
                "method": "GET",
                "name": "Nexus NuGet hosted repository ping",
                "timeout": "5s"
              }
            ],
            "enableTagOverride": true,
            "id": "nexus_nuget_mirror_api",
            "name": "artefacts",
            "port": 8081,
            "tags": [
              "read-mirror-nuget"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-nuget-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-mirror.json')
        .with_content(consul_nexus_nuget_mirror_config_content)
    end
  end

  context 'disables the service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'disables the nexus service' do
      expect(chef_run).to disable_service('nexus')
    end

    it 'updates the nexus service' do
      expect(chef_run).to create_systemd_service('nexus').with(
        action: [:create],
        after: %w[network.target],
        description: 'nexus service',
        wanted_by: %w[multi-user.target],
        exec_start: '/opt/nexus/bin/nexus start',
        exec_stop: '/opt/nexus/bin/nexus stop',
        limit_nofile: 65_536,
        restart: 'on-abort',
        type: 'forking',
        user: 'nexus'
      )
    end
  end
end
