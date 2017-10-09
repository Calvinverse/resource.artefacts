# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: java
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL JAVA JDK
#

jdk_version = '9'
jdk_flavor = 'openjdk'

java_home = "/usr/lib/jvm/java-#{jdk_version}"
java_home += "-#{jdk_flavor}"
java_home += "-#{node['kernel']['machine'] == 'x86_64' ? 'amd64' : 'i386'}"
node.default['java']['java_home'] = java_home

apt_repository 'openjdk-r-ppa' do
  uri 'ppa:openjdk-r'
  distribution node['lsb']['codename']
end

# Install the JDK
apt_package "#{jdk_flavor}-#{jdk_version}-jre-headless" do
  action :install
  options %w[-o Dpkg::Options::=--force-overwrite]
  version '9~b114-0ubuntu1'
end

# Install java and the required fonts
# Because apparently we might need these fonts because we are running in headless mode
# see: https://wiki.jenkins-ci.org/display/JENKINS/Jenkins+got+java.awt.headless+problem
apt_package %w[libfontconfig1 fonts-dejavu fonts-dejavu-core fonts-dejavu-extra xvfb] do
  action :install
end

link '/usr/lib/jvm/default-java' do
  to java_home
end

ruby_block 'Set JAVA_HOME in /etc/environment' do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    file.insert_line_if_no_match(/^JAVA_HOME=/, "JAVA_HOME=#{node['java']['java_home']}")
    file.search_file_replace_line(/^JAVA_HOME=/, "JAVA_HOME=#{node['java']['java_home']}")
    file.write_file
  end
end
