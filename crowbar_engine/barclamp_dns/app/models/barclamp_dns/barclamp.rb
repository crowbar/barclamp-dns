# Copyright 2013, Dell 
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

class BarclampDns::Barclamp < Barclamp

  def transition(inst, name, state)
    @logger.debug("DNS transition: entering for #{name} for #{state}")

    #
    # If we are discovering the node, make sure that we add the dns client or server to the node
    #
    if state == "discovered"
      @logger.debug("DNS transition: handling for #{name} for #{state}: discovered")
      prop = @barclamp.get_proposal(inst)
      role = @barclamp.get_role("dns-server")
      
      return [400, "DNS Proposal is not active"] unless prop.active?

      pca = prop.active_config
      unless pca.roles.include?(role)
        @logger.debug("DNS transition: adding #{name} to dns-server role")
        result = add_role_to_instance_and_node(name, inst, "dns-server")
      end

      # Always add the dns client
      @logger.debug("DNS transition: adding #{name} to dns-client role")
      result = add_role_to_instance_and_node(name, inst, "dns-client")

      a = [200, ""] if result
      a = [400, "Failed to add role to node"] unless result
      @logger.debug("DNS transition: leaving for #{name} for #{state}: discovered")
      return a
    end

    @logger.debug("DNS transition: leaving for #{name} for #{state}")
    [200, ""]
  end


end
