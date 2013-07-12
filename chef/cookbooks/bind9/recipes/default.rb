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
require 'ipaddr'

package "bind9" do
  case node[:platform]
  when "centos","redhat", "suse"
    package_name "bind"
  end
  action :install
end
package "bind9utils" do
  case node[:platform]
  when "centos","redhat", "suse"
    package_name "bind-utils"
  end
  action :install
end

directory "/etc/bind"

node[:dns][:zone_files]=Array.new

def populate_soa_defaults(zone)
  [ :admin,
    :ttl,
    :serial,
    :slave_refresh,
    :slave_retry,
    :slave_expire,
    :negative_cache ].each do |k|
    zone[k] ||= node[:dns][k]
  end
  zone
end
def make_zone(zone)
  # copy over SOA records that we have not overridden
  populate_soa_defaults zone
  zonefile_entries=Array.new
  Chef::Log.debug "Processing zone: #{zone.inspect}"
  # Arrange for the forward lookup zone to be created.
  template "/etc/bind/db.#{zone[:domain]}" do
    source "db.erb"
    mode 0644
    owner "root"
    case node[:platform]
    when "ubuntu","debian" then group "bind"
    when "centos","redhat","suse" then group "named"
    end
    notifies :reload, "service[bind9]"
    variables(:zone => zone)
  end
  zonefile_entries << zone[:domain]

  # Arrange for reverse lookup zones to be created.
  # Since there is no elegant method for doing this that takes into account
  # CIDR or IPv6, do it the excessively ugly way and create one zone per IP.
  zone[:hosts].keys.sort.each do |hostname|
    host=zone[:hosts][hostname]
    [:ip4addr, :ip6addr].each do |addr|
      next unless host[addr]
      rev_zone=Mash.new
      populate_soa_defaults rev_zone
      rev_domain=IPAddr.new(host[addr]).reverse
      rev_zone[:domain]=rev_domain
      rev_zone[:nameservers]=["#{zone[:nameservers].first}"]
      rev_zone[:hosts] ||= Mash.new
      rev_zone[:hosts]["#{rev_domain}."] = Mash.new
      rev_zone[:hosts]["#{rev_domain}."][:pointer]= if hostname == "@"
                                                      "#{zone[:domain]}."
                                                    else
                                                      "#{hostname}.#{zone[:domain]}."
                                                    end
      Chef::Log.debug "Processing zone: #{rev_zone.inspect}"
      template "/etc/bind/db.#{rev_domain}" do
        source "db.erb"
        mode 0644
        owner "root"
        notifies :reload, "service[bind9]"
        variables(:zone => rev_zone)
      end
      zonefile_entries << rev_domain
    end
  end
  Chef::Log.debug "Creating zone file for zones: #{zonefile_entries.inspect}"
  template "/etc/bind/zone.#{zone[:domain]}" do
    source "zone.erb"
    mode 0644
    owner "root"
    case node[:platform]
    when "ubuntu","debian" then group "bind"
    when "centos","redhat","suse" then group "named"
    end
    notifies :reload, "service[bind9]"
    variables(:zones => zonefile_entries)
  end
  node[:dns][:zone_files] << "/etc/bind/zone.#{zone[:domain]}"
end

# Create our basic zone infrastructure.
node[:dns][:domain] ||= node[:fqdn].split('.')[1..-1].join(".")
node[:dns][:admin] ||= "support.#{node[:fqdn]}."
node[:dns][:ttl] ||= "1h"
node[:dns][:serial] ||= 0
node[:dns][:serial] += 1
node[:dns][:slave_refresh] ||= "1d"
node[:dns][:slave_retry] ||= "2h"
node[:dns][:slave_expire] ||= "4w"
node[:dns][:negative_cache] ||= "300"
node[:dns][:zones] ||= Mash.new
zones = Mash.new
localdomain = Mash.new
localdomain[:nameservers]=["#{node[:fqdn]}."]
localdomain[:domain]="localhost"
localdomain[:hosts] ||= Mash.new
localdomain[:hosts]["@"] ||= Mash.new
localdomain[:hosts]["@"][:ip4addr]="127.0.0.1"
localdomain[:hosts]["@"][:ip6addr]="::1"
zones["localhost"] = localdomain

cluster_zone=Mash.new
cluster_zone[:domain] ||= node[:dns][:domain]
cluster_zone[:hosts] ||= Mash.new
cluster_zone[:nameservers] ||= ["#{node[:fqdn]}."]
populate_soa_defaults(cluster_zone)
# Get the config environment filter
#env_filter = "dns_config_environment:#{node[:dns][:config][:environment]}"
env_filter = "*:*" # Get all nodes for now.  This is a hack around a timing issue in ganglia.
# Get the list of nodes
nodes = search(:node, "#{env_filter}")
nodes.each do |n|
  n = Node.load(n.name)
  cname = n["crowbar"]["display"]["alias"] rescue nil
  cname = nil unless cname && ! cname.empty?
  Chef::Recipe::Barclamp::Inventory.list_networks(n).each do |network|
    next unless network.address
    base_name = n[:fqdn].chomp(".#{node[:dns][:domain]}")
    alias_name = cname unless base_name == cname
    unless network.name == "admin"
      net_name = network.name.gsub('_','-')
      base_name = "#{net_name}.#{base_name}"
      alias_name = "#{net_name}.#{alias_name}" if alias_name
    end
    cluster_zone[:hosts][base_name] ||= Mash.new
    cluster_zone[:hosts][base_name][:ip4addr]=network.address
    cluster_zone[:hosts][base_name][:alias]=alias_name if alias_name
  end
end

# let's create records for allocated addresses which do not belong to a node
search(:crowbar, "id:*_network").each do |network|
  #this is not network, or at least there is no nodes
  next unless network.has_key?("allocated_by_name")
  net_name=network[:id].gsub(/_network$/, '').gsub('_','-')
  network[:allocated_by_name].each_key do |host|
    if search(:node, "fqdn:#{host}").size > 0 or not host.match(/.#{node[:dns][:domain]}$/)
      #this is node in crowbar terms or it not belong to our domain, so lets skip it
      next
    end
    base_name=host.chomp(".#{node[:dns][:domain]}")
    unless network.name == "admin"
      base_name="#{net_name}.#{base_name}"
    end
    cluster_zone[:hosts][base_name] ||= Mash.new
    cluster_zone[:hosts][base_name][:ip4addr]=network[:allocated_by_name][host][:address]
  end
end

zones[node[:dns][:domain]]=cluster_zone

case node[:platform]
when "redhat","centos"
  template "/etc/sysconfig/named" do
    source "redhat-sysconfig-named.erb"
    mode 0644
    owner "root"
    variables :options => { "OPTIONS" => "-c /etc/bind/named.conf" }
  end
when "suse"
  template "/etc/sysconfig/named" do
    source "suse-sysconfig-named.erb"
    mode 0644
    owner "root"
    variables :options => { "NAMED_ARGS" => "-c /etc/bind/named.conf" }
  end
end

service "bind9" do
  case node[:platform]
  when "centos","redhat","suse"
    service_name "named"
  end
  supports :restart => true, :status => true, :reload => true
  running true
  enabled true
  action :enable
end

# Load up our default zones.  These never change.
files=%w{db.0 db.255 named.conf.default-zones}
files.each do |file|
  template "/etc/bind/#{file}" do
    source "#{file}.erb"
    case node[:platform]
    when "ubuntu","debian" then group "bind"
    when "centos","redhat","suse" then group "named"
    end
    mode 0644
    owner "root"
    notifies :reload, "service[bind9]"
  end
end

# If we don't have a local named.conf.local, create one.
# We keep this around to let local users add stuff to
# DNS that Crowbar will not manage.

bash "/etc/bind/named.conf.local" do
  code "touch /etc/bind/named.conf.local"
  not_if { ::File.exists? "/etc/bind/named.conf.local" }
end

# Write out the zone databases that Crowbar will be responsible for.
zones.keys.sort.each do |zone|
  make_zone zones[zone]
end

# Update named.conf.crowbar to include the new zones.
template "/etc/bind/named.conf.crowbar" do
  source "named.conf.crowbar.erb"
  mode 0644
  owner "root"
  case node[:platform]
  when "ubuntu","debian" then group "bind"
  when "centos","redhat","suse" then group "named"
  end
  variables(:zonefiles => node[:dns][:zone_files])
  notifies :reload, "service[bind9]"
end

# Rewrite our default configuration file
template "/etc/bind/named.conf" do
  source "named.conf.erb"
  mode 0644
  owner "root"
  case node[:platform]
  when "ubuntu","debian" then group "bind"
  when "centos","redhat","suse" then group "named"
  end
  variables(:forwarders => node[:dns][:forwarders],
            :allow_transfer => node[:dns][:allow_transfer])
  notifies :restart, "service[bind9]", :immediately
end

node[:dns][:zones]=zones
include_recipe "resolver"
