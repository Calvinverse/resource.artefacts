# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::firewall' do
  context 'configures the firewall' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the default firewall' do
      expect(chef_run).to install_firewall('default')
    end

    it 'opens the SSH TCP port' do
      expect(chef_run).to create_firewall_rule('ssh').with(
        command: :allow,
        dest_port: 22,
        direction: :in,
        protocol: :tcp
      )
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Consul HTTP port' do
      expect(chef_run).to create_firewall_rule('consul-http').with(
        command: :allow,
        dest_port: 8500,
        direction: :in
      )
    end

    it 'opens the Consul DNS port' do
      expect(chef_run).to create_firewall_rule('consul-dns').with(
        command: :allow,
        dest_port: 8600,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Consul rpc port' do
      expect(chef_run).to create_firewall_rule('consul-rpc').with(
        command: :allow,
        dest_port: 8300,
        direction: :in
      )
    end

    it 'opens the Consul serf LAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-tcp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf LAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-lan-udp').with(
        command: :allow,
        dest_port: 8301,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Consul serf WAN TCP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-tcp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :tcp
      )
    end

    it 'opens the Consul serf WAN UDP port' do
      expect(chef_run).to create_firewall_rule('consul-serf-wan-udp').with(
        command: :allow,
        dest_port: 8302,
        direction: :in,
        protocol: :udp
      )
    end
  end

  context 'configures the firewall for statsd' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Statsd port' do
      expect(chef_run).to create_firewall_rule('telegraf-statsd').with(
        command: :allow,
        dest_port: 8125,
        direction: :in
      )
    end
  end

  context 'configures the firewall for unbound' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Unbound DNS UDP port' do
      expect(chef_run).to create_firewall_rule('unbound-dns-udp').with(
        command: :allow,
        dest_port: 53,
        direction: :in,
        protocol: :udp
      )
    end

    it 'opens the Unbound DNS TCP port' do
      expect(chef_run).to create_firewall_rule('unbound-dns-tcp').with(
        command: :allow,
        dest_port: 53,
        direction: :in,
        protocol: :tcp
      )
    end
  end
end
