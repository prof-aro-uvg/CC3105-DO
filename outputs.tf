output "droplet_ip_addresses" {
  description = "Droplet name => public IPv4"
  value       = module.groups.droplet_ip_addresses
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands (use the same key for any of the course users, e.g. cc3105)"
  value       = { for name, ip in module.groups.droplet_ip_addresses : name => "ssh mlops@${ip}" }
}
