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

class BarclampDns::BarclampsController < BarclampsController

  # Override proposal_create to inject default domain and support
  # attributes if we are creating one with a default proposal.

  def proposal_create
    dns = (params[:attributes][:dns] || Hash.new)
    if dns[:domain].nil? || (dns[:domain] == "pod.your.cloud.org")
      dns[:domain]=%x{hostname -d}.strip
      dns[:contact]="support@#{dns[:domain]}"
      params[:attributes] ||= Hash.new
      params[:attributes][:dns]=dns
    end
    super
  end
end

