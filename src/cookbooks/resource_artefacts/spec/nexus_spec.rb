# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

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

    it 'creates and mounts the nexus_npm file system at /srv/nexus/blob/npm' do
      expect(chef_run).to create_directory('/srv/nexus/blob/npm').with(
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

    it 'creates a blob store for production docker images' do
      expect(chef_run).to run_nexus3_api('docker-production-blob').with(
        content: "blobStore.createFileBlobStore('docker_production', '/srv/nexus/blob/docker/docker_production')"
      )
    end

    it 'creates a repository for production docker images' do
      expect(chef_run).to run_nexus3_api('docker-production').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-production', 5000, 5001, 'docker_production', true, true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for qa docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa-blob').with(
        content: "blobStore.createFileBlobStore('docker_qa', '/srv/nexus/blob/docker/docker_qa')"
      )
    end

    it 'creates a repository for qa docker images' do
      expect(chef_run).to run_nexus3_api('docker-qa').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createDockerHosted('docker-qa', 5010, 5011, 'docker_qa', true, true, WritePolicy.ALLOW)"
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

    it 'enables the docker bearer token realm' do
      expect(chef_run).to run_nexus3_api('docker-bearer-token').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('DockerToken', true);"
      )
    end
  end

  context 'creates npm repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production-blob').with(
        content: "blobStore.createFileBlobStore('npm_production', '/srv/nexus/blob/npm/npm_production')"
      )
    end

    it 'creates a repository for production npm packages' do
      expect(chef_run).to run_nexus3_api('npm-production').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-production', 'npm_production', true, WritePolicy.ALLOW_ONCE)"
      )
    end

    it 'creates a blob store for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa-blob').with(
        content: "blobStore.createFileBlobStore('npm_qa', '/srv/nexus/blob/npm/npm_qa')"
      )
    end

    it 'creates a repository for qa npm packages' do
      expect(chef_run).to run_nexus3_api('npm-qa').with(
        content: "import org.sonatype.nexus.repository.storage.WritePolicy; repository.createNpmHosted('npm-qa', 'npm_qa', true, WritePolicy.ALLOW)"
      )
    end

    it 'creates a blob store for mirrored npm packages' do
      expect(chef_run).to run_nexus3_api('npm-mirror-blob').with(
        content: "blobStore.createFileBlobStore('npm_mirror', '/srv/nexus/blob/scratch/npm_mirror')"
      )
    end

    it 'creates a repository for mirror npm packages' do
      expect(chef_run).to run_nexus3_api('npm-mirror').with(
        content: "repository.createNpmProxy('npmjs.org','https://www.npmjs.org/', 'npm_mirror', true)"
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

  context 'creates ruby gems repositories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a blob store for mirrored ruby gems packages' do
      expect(chef_run).to run_nexus3_api('gems-mirror-blob').with(
        content: "blobStore.createFileBlobStore('gems_mirror', '/srv/nexus/blob/scratch/gems_mirror')"
      )
    end

    it 'creates a repository for mirror ruby gems packages' do
      expect(chef_run).to run_nexus3_api('gems-mirror').with(
        content: "repository.createRubygemsProxy('rubygems.org','https://rubygems.org', 'gems_mirror', true)"
      )
    end
  end

  context 'configures the firewall for nexus' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Nexus HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-http').with(
        command: :allow,
        dest_port: nexus_management_port,
        direction: :in
      )
    end

    it 'opens the Docker production repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-http').with(
        command: :allow,
        dest_port: 5000,
        direction: :in
      )
    end

    it 'opens the Docker production repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-production-https').with(
        command: :allow,
        dest_port: 5001,
        direction: :in
      )
    end

    it 'opens the Docker qa repository HTTP port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-http').with(
        command: :allow,
        dest_port: 5010,
        direction: :in
      )
    end

    it 'opens the Docker qa repository HTTPs port' do
      expect(chef_run).to create_firewall_rule('nexus-docker-qa-https').with(
        command: :allow,
        dest_port: 5011,
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
    it 'creates the /etc/consul/conf.d/nexus-management.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-management.json')
        .with_content(consul_nexus_management_config_content)
    end

    consul_nexus_docker_production_config_content = <<~JSON
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
            "port": 5000,
            "tags": [
              "read-production-docker",
              "write-production-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-production.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-production.json')
        .with_content(consul_nexus_docker_production_config_content)
    end

    consul_nexus_docker_qa_config_content = <<~JSON
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
            "port": 5010,
            "tags": [
              "read-qa-docker",
              "write-qa-docker"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/nexus-docker-qa.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-docker-qa.json')
        .with_content(consul_nexus_docker_qa_config_content)
    end

    consul_nexus_docker_mirror_config_content = <<~JSON
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
            "port": 5020,
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

    consul_nexus_npm_production_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-npm-production.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-production.json')
        .with_content(consul_nexus_npm_production_config_content)
    end

    consul_nexus_npm_qa_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-npm-qa.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-qa.json')
        .with_content(consul_nexus_npm_qa_config_content)
    end

    consul_nexus_npm_mirror_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-npm-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-npm-mirror.json')
        .with_content(consul_nexus_npm_mirror_config_content)
    end

    consul_nexus_nuget_production_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-nuget-production.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-production.json')
        .with_content(consul_nexus_nuget_production_config_content)
    end

    consul_nexus_nuget_mirror_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-nuget-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-nuget-mirror.json')
        .with_content(consul_nexus_nuget_mirror_config_content)
    end

    consul_nexus_gems_mirror_config_content = <<~JSON
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
    it 'creates the /etc/consul/conf.d/nexus-gems-mirror.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus-gems-mirror.json')
        .with_content(consul_nexus_gems_mirror_config_content)
    end
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-infrastructure-container-pull role' do
      expect(chef_run).to run_nexus3_api('role-docker-pull').with(
        content: "security.addRole('nx-infrastructure-container-pull', 'nx-infrastructure-container-pull'," \
        " 'User with privileges to allow pulling containers from the different container repositories'," \
        " ['nx-repository-view-docker-production-browse', 'nx-repository-view-docker-production-read'], [''])"
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

    it 'create a nx-builds-pull-npm role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-npm').with(
        content: "security.addRole('nx-builds-pull-npm', 'nx-builds-pull-npm'," \
        " 'User with privileges to allow pulling packages from the different npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-npm role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-npm').with(
        content: "security.addRole('nx-builds-push-npm', 'nx-builds-push-npm'," \
        " 'User with privileges to allow pushing packages to the different npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read', 'nx-repository-view-npm-*-add', 'nx-repository-view-npm-*-edit'], [''])"
      )
    end

    it 'create a nx-builds-pull-nuget role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-nuget').with(
        content: "security.addRole('nx-builds-pull-nuget', 'nx-builds-pull-nuget'," \
        " 'User with privileges to allow pulling packages from the different nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
      )
    end

    it 'create a nx-builds-push-nuget role' do
      expect(chef_run).to run_nexus3_api('role-builds-push-nuget').with(
        content: "security.addRole('nx-builds-push-nuget', 'nx-builds-push-nuget'," \
        " 'User with privileges to allow pushing packages to the different nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read', 'nx-repository-view-nuget-*-add', 'nx-repository-view-nuget-*-edit'], [''])"
      )
    end

    it 'create a nx-builds-pull-rubygems role' do
      expect(chef_run).to run_nexus3_api('role-builds-pull-rubygems').with(
        content: "security.addRole('nx-builds-pull-rubygems', 'nx-builds-pull-rubygems'," \
        " 'User with privileges to allow pulling packages from the different rubygems repositories'," \
        " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
      )
    end

    it 'create a nx-developer-docker role' do
      expect(chef_run).to run_nexus3_api('role-developer-docker').with(
        content: "security.addRole('nx-developer-docker', 'nx-developer-docker'," \
        " 'User with privileges to allow pulling containers from the docker repositories'," \
        " ['nx-repository-view-docker-*-browse', 'nx-repository-view-docker-*-read'], [''])"
      )
    end

    it 'create a nx-developer-npm role' do
      expect(chef_run).to run_nexus3_api('role-developer-npm').with(
        content: "security.addRole('nx-developer-npm', 'nx-developer-npm'," \
        " 'User with privileges to allow pulling packages from the npm repositories'," \
        " ['nx-repository-view-npm-*-browse', 'nx-repository-view-npm-*-read'], [''])"
      )
    end

    it 'create a nx-developer-nuget role' do
      expect(chef_run).to run_nexus3_api('role-developer-nuget').with(
        content: "security.addRole('nx-developer-nuget', 'nx-developer-nuget'," \
        " 'User with privileges to allow pulling packages from the nuget repositories'," \
        " ['nx-repository-view-nuget-*-browse', 'nx-repository-view-nuget-*-read'], [''])"
      )
    end

    it 'create a nx-developer-rubygems role' do
      expect(chef_run).to run_nexus3_api('role-developer-rubygems').with(
        content: "security.addRole('nx-developer-rubygems', 'nx-developer-rubygems'," \
        " 'User with privileges to allow pulling packages from the ruby gems repositories'," \
        " ['nx-repository-view-rubygems-*-browse', 'nx-repository-view-rubygems-*-read'], [''])"
      )
    end

    it 'create a nx-developer-search role' do
      expect(chef_run).to run_nexus3_api('role-developer-search').with(
        content: "security.addRole('nx-developer-search', 'nx-developer-search'," \
        " 'User with privileges to allow searching for packages in the different repositories'," \
        " ['nx-search-read', 'nx-selectors-read'], [''])"
      )
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

  context 'enables the reverse proxy path' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    nexus_properties_content = <<~PROPERTIES
      # Jetty section
      application-port=#{nexus_management_port}
      application-host=0.0.0.0
      nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-requestlog.xml
      nexus-context-path=#{nexus_proxy_path}
    PROPERTIES
    it 'creates the /home/nexus/etc/nexus.properties' do
      expect(chef_run).to create_file('/home/nexus/etc/nexus.properties')
        .with_content(nexus_properties_content)
    end
  end
end
