
name "dns-server"
description "DNS Server Role - DNS server for the cloud"
run_list(
         "recipe[bind9]"
)
default_attributes "dns" => {
  "static" => {},
  "forwarders" => [],
  "domain" => "",
  "contact" => "support@localhost.localdomain",
  "config" => { "environment" => "dns-base-config" }
}
override_attributes()

