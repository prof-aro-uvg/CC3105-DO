output "droplet_ip_addresses" {
  description = "Droplet name => public IPv4"
  value       = { for d in digitalocean_droplet.droplets : d.name => d.ipv4_address }
}

output "droplet_ids" {
  description = "Droplet name => droplet ID"
  value       = { for d in digitalocean_droplet.droplets : d.name => d.id }
}
