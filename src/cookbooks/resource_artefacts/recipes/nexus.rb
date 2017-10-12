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

# Set the number of file handles for the given user
# See here: https://help.sonatype.com/display/NXRM3/System+Requirements#filehandles
file '/etc/security/limits.conf' do
  action :create
  content <<~CONF
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
  CONF
end

#
# INSTALL NEXUS
#

nexus3 'nexus' do
  action :install
  group node['nexus']['service_group']
  user node['nexus']['service_user']
end

# Disable anonymous access
nexus3_api 'anonymous' do
  action :run
  content 'security.setAnonymousAccess(false)'
end

#
# ALLOW NEXUS THROUGH THE FIREWALL
#

firewall_rule 'nexus-http' do
  command :allow
  description 'Allow Nexus HTTP traffic'
  dest_port 8081
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

file '/etc/consul/conf.d/nexus.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "header": { "Authorization" : []}
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus API ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "active",
            "read",
            "write"
          ]
        },
        {
          "checks" :[
            {
              "header": { "Authorization" : []}
              "http": "http://localhost:8081/service/metrics/ping",
              "id": "nexus_api_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Nexus API ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "nexus_api",
          "name": "artefacts",
          "port": 8081,
          "tags": [
            "management",
            "edgeproxyprefix-/artefacts"
          ]
        }
      ]
    }
  JSON
end

#
# DISABLE THE SERVICE
#

# Make sure the nexus service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
end
