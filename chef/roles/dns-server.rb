
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
  "ttl" => "1h",
  "serial" => 1,
  "slave_refresh" => "1d",
  "slave_retry" => "2h",
  "slave_expire" => "4w",
  "negative_cache" => 300,
  "config" => { "environment" => "dns-base-config" }
}
override_attributes()

