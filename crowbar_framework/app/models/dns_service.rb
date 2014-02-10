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

class DnsService < ServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "dns"
  end

  def create_proposal
    @logger.debug("DNS create_proposal: entering")
    base = super
    @logger.debug("DNS create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_at_least_n_for_role proposal, "dns-server", 1

    super
  end

  def transition(inst, name, state)
    @logger.debug("DNS transition: entering for #{name} for #{state}")

    #
    # If we are discovering the node, make sure that we add the dns client or server to the node
    #
    if state == "discovered"
      @logger.debug("DNS transition: handling for #{name} for #{state}: discovered")
      db = ProposalObject.find_proposal "dns", inst
      role = RoleObject.find_role_by_name "dns-config-#{inst}"

      if role.override_attributes["dns"]["elements"]["dns-server"].nil? or
         role.override_attributes["dns"]["elements"]["dns-server"].empty?
        @logger.debug("DNS transition: adding #{name} to dns-server role")
        result = add_role_to_instance_and_node("dns", inst, name, db, role, "dns-server")
      end

      # Always add the dns client
      @logger.debug("DNS transition: adding #{name} to dns-client role")
      result = add_role_to_instance_and_node("dns", inst, name, db, role, "dns-client")

      a= [200, NodeObject.find_node_by_name(name).to_hash ] if result
      a = [400, "Failed to add role to node"] unless result
      @logger.debug("DNS transition: leaving for #{name} for #{state}: discovered")
      return a
    end

    @logger.debug("DNS transition: leaving for #{name} for #{state}")
    [200, NodeObject.find_node_by_name(name).to_hash ]
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("DNS apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    slave_ips = []
    nodes = NodeObject.all
    admin = nodes.select { |n| n.admin? }
    tnodes = role.override_attributes["dns"]["elements"]["dns-server"]

    slave_nodes = tnodes

    # electing master dns-server
    master = nil
    tnodes.each do |n|
      node = NodeObject.find_node_by_name n
      if node[:dns][:master]
        master = node
        break
      end
    end
    if master.nil?
      if tnodes.include?(admin[0].name)
        master = admin[0]
      else
        master = NodeObject.find_node_by_name tnodes.shift
      end
    end

    slave_nodes.delete(master.name)
    slave_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      slave_ips << node[:crowbar][:network][:admin][:address]
    end

    master[:dns][:master] = true
    master[:dns][:master_ip] = master[:crowbar][:network][:admin][:address]
    master[:dns][:slave_ips] = slave_ips
    master[:dns][:slave_names] = slave_nodes
    master.save

    slave_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      node[:dns][:master_ip] = master[:crowbar][:network][:admin][:address]
      node[:dns][:slave_ips] = slave_ips
      node[:dns][:slave_names] = slave_nodes
      node[:dns][:master] = false
      node.save
    end

    @logger.debug("DNS apply_role_pre_chef_call: leaving")
  end

end
