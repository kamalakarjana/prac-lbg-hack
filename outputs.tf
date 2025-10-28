output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "web_vm_private_ips" {
  value = [for nic in azurerm_network_interface.web : nic.private_ip_address]
}

output "app_vm_private_ips" {
  value = [for nic in azurerm_network_interface.app : nic.private_ip_address]
}

output "web_vm_names" {
  value = [for vm in azurerm_linux_virtual_machine.web : vm.name]
}

output "app_vm_names" {
  value = [for vm in azurerm_linux_virtual_machine.app : vm.name]
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "load_balancer_url" {
  value = "http://${azurerm_public_ip.lb.ip_address}"
}

output "deployment_summary" {
  value = <<EOT

?? DEPLOYMENT SUCCESSFUL!

Resource Group: ${azurerm_resource_group.main.name}
Location: ${azurerm_resource_group.main.location}

Web Tier VMs (2):
${join("\n", [for i, vm in azurerm_linux_virtual_machine.web : "  - ${vm.name} (${azurerm_network_interface.web[i].private_ip_address})"])}

App Tier VMs (2):
${join("\n", [for i, vm in azurerm_linux_virtual_machine.app : "  - ${vm.name} (${azurerm_network_interface.app[i].private_ip_address})"])}

?? LOAD BALANCER ACCESS:
Load Balancer Public IP: ${azurerm_public_ip.lb.ip_address}
Access URL: http://${azurerm_public_ip.lb.ip_address}

Test Nginx by opening the URL above in your browser!
The load balancer will distribute traffic between both web servers.

EOT
}