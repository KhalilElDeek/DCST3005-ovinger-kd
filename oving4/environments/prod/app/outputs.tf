output "vm_name" {
  value = module.compute.vm_name
}

output "private_ip" {
  value = module.compute.private_ip
}

output "brukt_subnet_id" {
  value       = local.subnet_id
  description = "Subnett-ID-en hentet fra networks-stackens outputs"
}