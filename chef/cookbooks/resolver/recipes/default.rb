#
# Cookbook Name:: resolver
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
# Copyright 2011, Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

env_filter = " AND dns_config_environment:#{node[:dns][:config][:environment]}"
nodes = search(:node, "roles:dns-server")

dns_list = []
if !nodes.nil? and !nodes.empty?
  dns_list = nodes.map { |x| Chef::Recipe::Barclamp::Inventory.get_network_by_type(x, "admin").address }
end
dns_list << node[:dns][:nameservers]

template "/etc/resolv.conf" do
  source "resolv.conf.erb"
  owner "root"
  group "root"
  mode 0644
  variables(:nameservers => dns_list.flatten, :search => node[:dns][:domain])
end
