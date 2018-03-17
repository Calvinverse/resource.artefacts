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

  context 'creates the LDAP realm' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'enables the ldap realm' do
      expect(chef_run).to run_nexus3_api('ldap-realm').with(
        content: 'import org.sonatype.nexus.security.realm.RealmManager;' \
        'realmManager = container.lookup(RealmManager.class.getName());' \
        "realmManager.enableRealm('LdapRealm', true);"
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

    it 'forces the firewall rules to be set' do
      expect(chef_run).to restart_firewall('default')
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
  end

  context 'create roles and users' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'create a nx-developer-search role' do
      expect(chef_run).to run_nexus3_api('role-developer-search').with(
        content: "security.addRole('nx-developer-search', 'nx-developer-search'," \
        " 'User with privileges to allow searching for packages in the different repositories'," \
        " ['nx-search-read', 'nx-selectors-read'], [''])"
      )
    end
  end
end
