output "droplet_ip_addresses" {
  description = "Droplet name => public IPv4"
  value       = module.groups.droplet_ip_addresses
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands for the mlops user"
  value       = { for name, ip in module.groups.droplet_ip_addresses : name => "ssh mlops@${ip}" }
}
