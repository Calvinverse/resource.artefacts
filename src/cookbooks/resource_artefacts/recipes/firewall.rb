# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: firewall
#
# Copyright 2017, P. van der Velde
#

firewall 'default' do
  action :install
end

firewall_rule 'ssh' do
  command :allow
  description 'Allow SSH traffic'
  dest_port 22
  direction :in
end
