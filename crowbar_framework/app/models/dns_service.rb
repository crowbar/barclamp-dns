#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class DnsService < ServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "dns"
  end

  class << self
    def role_constraints
      {
        "dns-server" => {
          "unique" => false,
          "count" => 7,
          "admin" => true,
          "exclude_platform" => {
            "windows" => "/.*/"
          }
        },
        "dns-client" => {
          "unique" => false,
          "count" => -1,
          "admin" => true
        }
      }
    end
  end

  def create_proposal
    @logger.debug("DNS create_proposal: entering")
    base = super
    @logger.debug("DNS create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    server_role = proposal["deployment"]["dns"]["elements"]["dns-server"]
    nameservers = proposal["attributes"]["dns"]["nameservers"]

    if server_role.blank? && nameservers.blank?
      validation_error("At least one nameserver or one node with the dns-server role must be specified.")
    end

    super
  end

  def transition(inst, name, state)
    @logger.debug("DNS transition: entering for #{name} for #{state}")

    #
    # If we are discovering the node, make sure that we add the dns client or server to the node
    #
    if state == "discovered"
      @logger.debug("DNS transition: handling for #{name} for #{state}: discovered")
      db = Proposal.where(barclamp: "dns", name: inst).first
      role = RoleObject.find_role_by_name "dns-config-#{inst}"

      if role.default_attributes["dns"]["auto_assign_server"]
        if role.override_attributes["dns"]["elements"]["dns-server"].nil? or
           role.override_attributes["dns"]["elements"]["dns-server"].empty?
          @logger.debug("DNS transition: adding #{name} to dns-server role")
          result = add_role_to_instance_and_node("dns", inst, name, db, role, "dns-server")
        end
      end

      # Always add the dns client
      @logger.debug("DNS transition: adding #{name} to dns-client role")
      result = add_role_to_instance_and_node("dns", inst, name, db, role, "dns-client")

      a = [200, { :name => name } ] if result
      a = [400, "Failed to add role to node"] unless result
      @logger.debug("DNS transition: leaving for #{name} for #{state}: discovered")
      return a
    end

    @logger.debug("DNS transition: leaving for #{name} for #{state}")
    [200, { :name => name } ]
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("DNS apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    tnodes = role.override_attributes["dns"]["elements"]["dns-server"]

    if !tnodes.blank?
      nodes = tnodes.map {|n| NodeObject.find_node_by_name n}
      # electing master dns-server
      master = nil
      admin = nil
      nodes.each do |node|
        if node[:dns][:master]
          master = node
          break
        elsif node.admin?
          admin = node
        end
      end
      if master.nil?
        unless admin.nil?
          master = admin
        else
          master = nodes.first
        end
      end

      slave_ips = nodes.map {|n| n[:crowbar][:network][:admin][:address]}
      slave_ips.delete(master[:crowbar][:network][:admin][:address])
      slave_nodes = tnodes.dup
      slave_nodes.delete(master.name)

      nodes.each do |node|
        node.set[:dns][:master_ip] = master[:crowbar][:network][:admin][:address]
        node.set[:dns][:slave_ips] = slave_ips
        node.set[:dns][:slave_names] = slave_nodes
        node.set[:dns][:master] = (master.name == node.name)
        node.save
      end
    end

    @logger.debug("DNS apply_role_pre_chef_call: leaving")
  end

end
