# frozen_string_literal: true

chef_version '>= 12.5' if respond_to?(:chef_version)
description 'Environment cookbook that configures a Linux server as an artefact server.'
issues_url '${ProductUrl}/issues' if respond_to?(:issues_url)
license 'Apache-2.0'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
name 'resource_artefacts'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
source_url '${ProductUrl}' if respond_to?(:source_url)
version '${VersionSemantic}'

supports 'ubuntu', '>= 16.04'

depends 'firewall', '= 2.6.3'
depends 'nexus3', '= 3.3.0'
depends 'java', '= 4.0.0'
depends 'poise-service', '= 1.5.2'
depends 'systemd', '= 3.2.3'
