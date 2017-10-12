# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::nexus' do
  context 'creates the nexus user' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the user' do
      expect(chef_run).to create_user('nexus').with(
        gid: 'nexus',
        home: '/home/nexus',
        system: true,
        uid: nil,
        shell: '/bin/false'
      )
    end

    etc_security_config_content = <<~HCL
      # /etc/security/limits.conf
      #
      #Each line describes a limit for a user in the form:
      #
      #<domain>        <type>  <item>  <value>
      #
      #Where:
      #<domain> can be:
      #        - a user name
      #        - a group name, with @group syntax
      #        - the wildcard *, for default entry
      #        - the wildcard %, can be also used with %group syntax,
      #                 for maxlogin limit
      #        - NOTE: group and wildcard limits are not applied to root.
      #          To apply a limit to the root user, <domain> must be
      #          the literal username root.
      #
      #<type> can have the two values:
      #        - "soft" for enforcing the soft limits
      #        - "hard" for enforcing hard limits
      #
      #<item> can be one of the following:
      #        - core - limits the core file size (KB)
      #        - data - max data size (KB)
      #        - fsize - maximum filesize (KB)
      #        - memlock - max locked-in-memory address space (KB)
      #        - nofile - max number of open files
      #        - rss - max resident set size (KB)
      #        - stack - max stack size (KB)
      #        - cpu - max CPU time (MIN)
      #        - nproc - max number of processes
      #        - as - address space limit (KB)
      #        - maxlogins - max number of logins for this user
      #        - maxsyslogins - max number of logins on the system
      #        - priority - the priority to run user process with
      #        - locks - max number of file locks the user can hold
      #        - sigpending - max number of pending signals
      #        - msgqueue - max memory used by POSIX message queues (bytes)
      #        - nice - max nice priority allowed to raise to values: [-20, 19]
      #        - rtprio - max realtime priority
      #        - chroot - change root to directory (Debian-specific)
      #
      #<domain>      <type>  <item>         <value>
      #

      #*               soft    core            0
      #root            hard    core            100000
      #*               hard    rss             10000
      #@student        hard    nproc           20
      #@faculty        soft    nproc           20
      #@faculty        hard    nproc           50
      #ftp             hard    nproc           0
      #ftp             -       chroot          /ftp
      #@student        -       maxlogins       4

      # Give the nexus user lots of file handles so that nexus doesn't lose data
      nexus - nofile 65536

      # End of file
    HCL
    it 'updates the /etc/security/limits.conf to have many file handles for Nexus' do
      expect(chef_run).to create_file('/etc/security/limits.conf')
        .with_content(etc_security_config_content)
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

    consul_service_config_content = <<~JSON

    JSON
    it 'creates the /etc/consul/conf.d/nexus.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/nexus.json')
        .with_content(consul_service_config_content)
    end
  end

  context 'disables the service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'disables the nexus service' do
      expect(chef_run).to disable_service('nexus')
    end
  end
end
