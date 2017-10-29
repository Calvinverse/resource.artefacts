# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::network' do
  unbound_config_directory = '/etc/unbound.d'

  context 'create the unbound locations' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the unbound config directory' do
      expect(chef_run).to create_directory(unbound_config_directory)
    end
  end

  context 'installs unbound' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the unbound binaries' do
      expect(chef_run).to install_apt_package('unbound').with(
        version: '1.5.8-1ubuntu1'
      )
    end

    unbound_default_config_content = <<~CONF
      #
      # See unbound.conf(5) man page, version 1.6.3.
      #

      # Use this to include other text into the file.
      include: "#{unbound_config_directory}/unbound_zones.conf"

      # The server clause sets the main parameters.
      server:
          # whitespace is not necessary, but looks cleaner.

          # verbosity number, 0 is least verbose. 1 is default, 4 is maximum.
          verbosity: 1

          # specify the interfaces to answer queries from by ip-address.
          # The default is to listen to localhost (127.0.0.1 and ::1).
          # specify 0.0.0.0 and ::0 to bind to all available interfaces.
          # specify every interface[@port] on a new 'interface:' labelled line.
          # The listen interfaces are not changed on reload, only on restart.
          interface: 127.0.0.1

          # port to answer queries from
          port: 53

          # specify the interfaces to send outgoing queries to authoritative
          # server from by ip-address. If none, the default (all) interface
          # is used. Specify every interface on a 'outgoing-interface:' line.
          # outgoing-interface: 192.0.2.153

          # deny unbound the use this of port number or port range for
          # making outgoing queries, using an outgoing interface.
          # Use this to make sure unbound does not grab a UDP port that some
          # other server on this computer needs. The default is to avoid
          # IANA-assigned port numbers.
          # If multiple outgoing-port-permit and outgoing-port-avoid options
          # are present, they are processed in order.
          outgoing-port-avoid: "4600-4700, 8300-8700"

          # number of outgoing simultaneous tcp buffers to hold per thread.
          outgoing-num-tcp: 10

          # number of incoming simultaneous tcp buffers to hold per thread.
          incoming-num-tcp: 10

          # buffer size for UDP port 53 incoming (SO_RCVBUF socket option).
          # 0 is system default.  Use 4m to catch query spikes for busy servers.
          so-rcvbuf: 0

          # buffer size for UDP port 53 outgoing (SO_SNDBUF socket option).
          # 0 is system default.  Use 4m to handle spikes on very busy servers.
          so-sndbuf: 0

          # Maximum UDP response size (not applied to TCP response).
          # Suggested values are 512 to 4096. Default is 4096. 65536 disables it.
          max-udp-size: 4096

          # buffer size for handling DNS data. No messages larger than this
          # size can be sent or received, by UDP or TCP. In bytes.
          msg-buffer-size: 65552

          # the amount of memory to use for the message cache.
          # plain value in bytes or you can append k, m or G. default is "4Mb".
          msg-cache-size: 4m

          # the number of slabs to use for the message cache.
          # the number of slabs must be a power of 2.
          # more slabs reduce lock contention, but fragment memory usage.
          msg-cache-slabs: 4

          # the number of queries that a thread gets to service.
          num-queries-per-thread: 1024

          # if very busy, 50% queries run to completion, 50% get timeout in msec
          jostle-timeout: 200

          # the time to live (TTL) value lower bound, in seconds. Default 0.
          # If more than an hour could easily give trouble due to stale data.
          cache-min-ttl: 0

          # the time to live (TTL) value cap for RRsets and messages in the
          # cache. Items are not cached for longer. In seconds.
          cache-max-ttl: 86400

          # the time to live (TTL) value cap for negative responses in the cache
          cache-max-negative-ttl: 0

          # the time to live (TTL) value for cached roundtrip times, lameness and
          # EDNS version information for hosts. In seconds.
          infra-host-ttl: 900

          # minimum wait time for responses, increase if uplink is long. In msec.
          infra-cache-min-rtt: 50

          # the maximum number of hosts that are cached (roundtrip, EDNS, lame).
          infra-cache-numhosts: 10000

          # Enable IPv4, "yes" or "no".
          do-ip4: yes

          # Enable IPv6, "yes" or "no".
          do-ip6: no

          # Enable UDP, "yes" or "no".
          do-udp: yes

          # Enable TCP, "yes" or "no".
          do-tcp: yes

          # upstream connections use TCP only (and no UDP), "yes" or "no"
          # useful for tunneling scenarios, default no.
          tcp-upstream: no

          # Maximum segment size (MSS) of TCP socket on which the server
          # responds to queries. Default is 0, system default MSS.
          tcp-mss: 0

          # Maximum segment size (MSS) of TCP socket for outgoing queries.
          # Default is 0, system default MSS.
          outgoing-tcp-mss: 0

          # Use systemd socket activation for UDP, TCP, and control sockets.
          # use-systemd: yes

          # Detach from the terminal, run in background, "yes" or "no".
          # Set the value to "no" when unbound runs as systemd service.
          do-daemonize: no

          # control which clients are allowed to make (recursive) queries
          # to this server. Specify classless netblocks with /size and action.
          # By default everything is refused, except for localhost.
          # Choose deny (drop message), refuse (polite error reply),
          # allow (recursive ok), allow_snoop (recursive and nonrecursive ok)
          # deny_non_local (drop queries unless can be answered from local-data)
          # refuse_non_local (like deny_non_local but polite error reply).
          access-control: 0.0.0.0/0 refuse
          access-control: 127.0.0.0/8 allow
          access-control: ::0/0 refuse
          access-control: ::1 allow
          access-control: ::ffff:127.0.0.1 allow

          # if given, a chroot(2) is done to the given directory.
          # i.e. you can chroot to the working directory, for example,
          # for extra security, but make sure all files are in that directory.
          #
          # If chroot is enabled, you should pass the configfile (from the
          # commandline) as a full path from the original root. After the
          # chroot has been performed the now defunct portion of the config
          # file path is removed to be able to reread the config after a reload.
          #
          # All other file paths (working dir, logfile, roothints, and
          # key files) can be specified in several ways:
          #   o as an absolute path relative to the new root.
          #   o as a relative path to the working directory.
          #   o as an absolute path relative to the original root.
          # In the last case the path is adjusted to remove the unused portion.
          #
          # The pid file can be absolute and outside of the chroot, it is
          # written just prior to performing the chroot and dropping permissions.
          #
          # Additionally, unbound may need to access /dev/random (for entropy).
          # How to do this is specific to your OS.
          #
          # If you give "" no chroot is performed. The path must not end in a /.
          chroot: ""

          # if given, user privileges are dropped (after binding port),
          # and the given username is assumed. Default is user "unbound".
          # If you give "" no privileges are dropped.
          username: "unbound"

          # the working directory. The relative files in this config are
          # relative to this directory. If you give "" the working directory
          # is not changed.
          # If you give a server: directory: dir before include: file statements
          # then those includes can be relative to the working directory.
          directory: ""

          # Log to syslog(3) if yes. The log facility LOG_DAEMON is used to
          # log to. If yes, it overrides the logfile.
          use-syslog: yes

          # Log identity to report. if empty, defaults to the name of argv[0]
          # (usually "unbound").
          # log-identity: ""

          # print UTC timestamp in ascii to logfile, default is epoch in seconds.
          log-time-ascii: yes

          # print one line with time, IP, name, type, class for every query.
          log-queries: yes

          # print one line per reply, with time, IP, name, type, class, rcode,
          # timetoresolve, fromcache and responsesize.
          # log-replies: yes

          # Harden against very small EDNS buffer sizes.
          harden-short-bufsize: yes

          # Harden against unseemly large queries.
          harden-large-queries: yes

          # Harden against out of zone rrsets, to avoid spoofing attempts.
          harden-glue: yes

          # Harden against receiving dnssec-stripped data. If you turn it
          # off, failing to validate dnskey data for a trustanchor will
          # trigger insecure mode for that zone (like without a trustanchor).
          # Default on, which insists on dnssec data for trust-anchored zones.
          harden-dnssec-stripped: yes

          # Harden against queries that fall under dnssec-signed nxdomain names.
          harden-below-nxdomain: yes

          # if yes, the above default do-not-query-address entries are present.
          # if no, localhost can be queried (for testing and debugging).
          do-not-query-localhost: no

          # By default, for a number of zones a small default 'nothing here'
          # reply is built-in.  Query traffic is thus blocked.  If you
          # wish to serve such zone you can unblock them by uncommenting one
          # of the nodefault statements below.
          # You may also have to use domain-insecure: zone to make DNSSEC work,
          # unless you have your own trust anchors for this zone.
          local-zone: "localhost." nodefault
          local-zone: "127.in-addr.arpa." nodefault
          # local-zone: "10.in-addr.arpa." nodefault
          # local-zone: "16.172.in-addr.arpa." nodefault
          # local-zone: "17.172.in-addr.arpa." nodefault
          # local-zone: "18.172.in-addr.arpa." nodefault
          # local-zone: "19.172.in-addr.arpa." nodefault
          # local-zone: "20.172.in-addr.arpa." nodefault
          # local-zone: "21.172.in-addr.arpa." nodefault
          # local-zone: "22.172.in-addr.arpa." nodefault
          # local-zone: "23.172.in-addr.arpa." nodefault
          # local-zone: "24.172.in-addr.arpa." nodefault
          # local-zone: "25.172.in-addr.arpa." nodefault
          # local-zone: "26.172.in-addr.arpa." nodefault
          # local-zone: "27.172.in-addr.arpa." nodefault
          # local-zone: "28.172.in-addr.arpa." nodefault
          # local-zone: "29.172.in-addr.arpa." nodefault
          # local-zone: "30.172.in-addr.arpa." nodefault
          # local-zone: "31.172.in-addr.arpa." nodefault
          local-zone: "168.192.in-addr.arpa." nodefault
          # local-zone: "0.in-addr.arpa." nodefault

          # If unbound is running service for the local host then it is useful
          # to perform lan-wide lookups to the upstream, and unblock the
          # long list of local-zones above.  If this unbound is a dns server
          # for a network of computers, disabled is better and stops information
          # leakage of local lan information.
          unblock-lan-zones: yes

          # The insecure-lan-zones option disables validation for
          # these zones, as if they were all listed as domain-insecure.
          insecure-lan-zones: yes
    CONF
    it 'creates unboundconfiguration.ini in the /etc/unbound directory' do
      expect(chef_run).to create_file('/etc/unbound/unbound.conf').with_content(unbound_default_config_content)
    end
  end

  context 'install unbound as service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the unbound service' do
      expect(chef_run).to create_systemd_service('unbound').with(
        action: [:create],
        after: %w[multi-user.target],
        description: 'Unbound DNS proxy',
        documentation: 'http://www.unbound.net',
        requires: %w[multi-user.target]
      )
    end

    it 'disables the unbound service' do
      expect(chef_run).to disable_service('unbound')
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

  context 'points DNS requests to localhost' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    dhcpconf_content = <<~CONF
      # Configuration file for /sbin/dhclient.
      #
      # This is a sample configuration file for dhclient. See dhclient.conf's
      #       man page for more information about the syntax of this file
      #       and a more comprehensive list of the parameters understood by
      #       dhclient.
      #
      # Normally, if the DHCP server provides reasonable information and does
      #       not leave anything out (like the domain name, for example), then
      #       few changes must be made to this file, if any.
      #

      option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

      send host-name = gethostname();
      request subnet-mask, broadcast-address, time-offset, routers,
              domain-name, domain-name-servers, domain-search, host-name,
              dhcp6.name-servers, dhcp6.domain-search, dhcp6.fqdn, dhcp6.sntp-servers,
              netbios-name-servers, netbios-scope, interface-mtu,
              rfc3442-classless-static-routes, ntp-servers;

      #send dhcp-client-identifier 1:0:a0:24:ab:fb:9c;
      #send dhcp-lease-time 3600;
      supersede domain-name-servers 127.0.0.1;
      #prepend domain-name-servers 127.0.0.1;
      #require subnet-mask, domain-name-servers;
      timeout 300;
      #retry 60;
      #reboot 10;
      #select-timeout 5;
      #initial-interval 2;
      #script "/sbin/dhclient-script";
      #media "-link0 -link1 -link2", "link0 link1";
      #reject 192.33.137.209;

      #alias {
      #  interface "eth0";
      #  fixed-address 192.5.5.213;
      #  option subnet-mask 255.255.255.255;
      #}

      #lease {
      #  interface "eth0";
      #  fixed-address 192.33.137.200;
      #  medium "link0 link1";
      #  option host-name "andare.swiftmedia.com";
      #  option subnet-mask 255.255.255.0;
      #  option broadcast-address 192.33.137.255;
      #  option routers 192.33.137.250;
      #  option domain-name-servers 127.0.0.1;
      #  renew 2 2000/1/12 00:00:01;
      #  rebind 2 2000/1/12 00:00:01;
      #  expire 2 2000/1/12 00:00:01;
      #}
    CONF
    it 'adds localhost to the resolvconf base file' do
      expect(chef_run).to create_file('/etc/dhcp/dhclient.conf').with_content(dhcpconf_content)
    end
  end
end
