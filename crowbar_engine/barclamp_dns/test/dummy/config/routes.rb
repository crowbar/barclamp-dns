Rails.application.routes.draw do

  mount BarclampDns::Engine => "/barclamp_dns"
end
