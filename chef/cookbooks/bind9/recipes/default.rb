# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "utils"

package "bind9" do
  case node[:platform]
  when "centos","redhat"
    package_name "bind"
  end
  action :install
end
package "bind9utils" do
  case node[:platform]
  when "centos","redhat"
    package_name "bind-utils"
  end
  action :install
end

directory "/etc/bind"

template "/etc/bind/named.conf" do
  source "named.conf.erb"
  variables(:forwarders => node[:dns][:forwarders])
  mode 0644
  owner "root"
  case node[:platform]
  when "ubuntu","debian" then group "bind"
  when "centos","redhat" then group "named"
  end
  notifies :restart, "service[bind9]"
end

template "/etc/bind/named.conf.default-zones" do
  source "named.conf.default-zones.erb"
  variables(:forwarders => node[:dns][:forwarders])
  mode 0644
  owner "root"
  case node[:platform]
  when "ubuntu","debian" then group "bind"
  when "centos","redhat" then group "named"
  end
  notifies :restart, "service[bind9]"
end

template "/etc/bind/named.conf.options" do
  source "named.conf.options.erb"
  variables(:forwarders => node[:dns][:forwarders])
  mode 0644
  owner "root"
  case node[:platform]
  when "ubuntu","debian" then group "bind"
  when "centos","redhat" then group "named"
  end
  notifies :restart, "service[bind9]"
end

case node[:platform]
when "redhat","centos"
  template "/etc/sysconfig/named" do
    source "redhat-sysconfig-named.erb"
    mode 0644
    owner "root"
    variables :options => { "OPTIONS" => "-c /etc/bind/named.conf.local" }
  end
end

service "bind9" do
  case node[:platform]
  when "centos","redhat"
    service_name "named"
  end
  supports :restart => true, :status => true, :reload => true
  running true
  enabled true
  action :enable
end

file "/etc/bind/hosts" do
  owner "root"
  group "root"
  mode 0644
  content ""
  action :create
  not_if do File.exists?("/etc/bind/hosts") end
end

file "/etc/bind/netargs" do
  owner "root"
  group "root"
  mode 0644
  content ""
  action :create
  not_if do File.exists?("/etc/bind/netargs") end
end

bash "build-domain-file" do
  code <<-EOH
    mkdir /tmp/tmp.$$
    cd /tmp/tmp.$$

    NET_ARGS=`cat /etc/bind/netargs | while read line
    do
      echo -n "$line "
    done`

    /opt/dell/bin/h2n -d #{node[:dns][:domain]} -u #{node[:dns][:contact]} $NET_ARGS -H /etc/bind/hosts -h localhost +c named.conf.local
    rm -f boot.cacheonly conf.cacheonly db.127.0.0 named.boot dns.hosts
    sed -i 's/"db/"\\/etc\\/bind\\/db/' named.conf.local
    grep zone named.conf.local | grep -v "zone \\".\\"" | grep -v "0.0.127" > named.conf.new
    mv named.conf.new named.conf.local
    cp * /etc/bind

    touch -r /etc/motd /etc/bind/hosts
    touch -r /etc/motd /etc/bind/netargs
    touch -r /etc/motd /etc/bind/named.conf.local

    rm -rf /tmp/tmp.$$
EOH
  only_if "test /etc/bind/netargs -nt /etc/bind/named.conf.local || test /etc/bind/hosts -nt /etc/bind/named.conf.local"
  notifies :restart, resources(:service => "bind9"), :immediately
end

# Get the config environment filter
env_filter = "dns_config_environment:#{node[:dns][:config][:environment]}"
# Get the list of nodes
nodes = search(:node, "#{env_filter}")
nodes.each do |n|
  aaalias = n["crowbar"]["display"]["alias"] rescue nil
  aaalias = nil if aaalias == ""

  Chef::Recipe::Barclamp::Inventory.list_networks(n).each do |network|
    next unless network.address
    base_name = "#{n[:fqdn].split(".")[0]} #{n[:fqdn]} " if network.name == "admin"
    hostname_str = "#{base_name}#{network.name}.#{n[:fqdn]}"
    hostname_str = "#{hostname_str} #{aaalias} #{aaalias}.#{n[:domain]}" if network.name == "admin" and aaalias
    hostname_str = "#{hostname_str} #{network.name}.#{aaalias}.#{n[:domain]}" if aaalias
    bind9_host network.address do
      hostname hostname_str
      action :add
    end

    bind9_net network.subnet do
      netmask network.netmask
      action :add
    end
  end
end

node[:dns][:static].each do |name,ip|
  bind9_host ip do
    hostname name
    action :add
  end
end

