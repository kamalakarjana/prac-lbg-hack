# Generate unique name
locals {
  timestamp = replace(timestamp(), "/[- UTC:]/", "")
  base_name = "webapp-${local.timestamp}"
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-webapp-${local.timestamp}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "WebApp"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-webapp"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}

# Create Subnets
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Network Security Groups
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Tier = "Web"
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "APP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    Tier = "App"
  }
}

# Associate NSG with Subnets
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Create Availability Sets
resource "azurerm_availability_set" "web" {
  name                         = "as-web"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_availability_set" "app" {
  name                         = "as-app"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Create Network Interfaces for Web VMs
resource "azurerm_network_interface" "web" {
  count               = 2
  name                = "nic-web-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Tier = "Web"
  }
}

# Create Network Interfaces for App VMs
resource "azurerm_network_interface" "app" {
  count               = 2
  name                = "nic-app-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Tier = "App"
  }
}

# Create Web Tier Virtual Machines
resource "azurerm_linux_virtual_machine" "web" {
  count               = 2
  name                = "vm-web-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size_web
  availability_set_id = azurerm_availability_set.web.id
  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  admin_username = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Web Server $(hostname)</h1><p>Deployed via Terraform</p>" > /var/www/html/index.html
  EOT
  )

  tags = {
    Tier = "Web"
    VM   = "web-${count.index + 1}"
  }
}

# Create App Tier Virtual Machines
resource "azurerm_linux_virtual_machine" "app" {
  count               = 2
  name                = "vm-app-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size_app
  availability_set_id = azurerm_availability_set.app.id
  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  admin_username = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nodejs npm
    mkdir -p /home/azureuser/app
    echo "App Server $(hostname) - Ready" > /home/azureuser/app/status.txt
  EOT
  )

  tags = {
    Tier = "App"
    VM   = "app-${count.index + 1}"
  }
}

# Data Disks for Web VMs
resource "azurerm_managed_disk" "web_data" {
  count                = 2
  name                 = "disk-web-${count.index + 1}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10

  tags = {
    Tier = "Web"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "web_data" {
  count              = 2
  managed_disk_id    = azurerm_managed_disk.web_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.web[count.index].id
  lun                = 10
  caching            = "ReadWrite"
}

# Data Disks for App VMs
resource "azurerm_managed_disk" "app_data" {
  count                = 2
  name                 = "disk-app-${count.index + 1}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10

  tags = {
    Tier = "App"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_data" {
  count              = 2
  managed_disk_id    = azurerm_managed_disk.app_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.app[count.index].id
  lun                = 10
  caching            = "ReadWrite"
}

# Load Balancer Resources
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Purpose = "LoadBalancer"
  }
}

resource "azurerm_lb" "web" {
  name                = "lb-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = {
    Tier = "Web"
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  loadbalancer_id = azurerm_lb.web.id
  name            = "backend-pool"
}

resource "azurerm_lb_probe" "web" {
  loadbalancer_id     = azurerm_lb.web.id
  name                = "http-probe"
  port                = 80
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "web" {
  loadbalancer_id                = azurerm_lb.web.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.web.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 4
  enable_floating_ip             = false
}

# Associate web VMs with load balancer backend pool
resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

# Load Balancer Outbound Rule (optional)
resource "azurerm_lb_outbound_rule" "web" {
  name                    = "outbound-rule"
  loadbalancer_id         = azurerm_lb.web.id
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id

  frontend_ip_configuration {
    name = "frontend"
  }

  allocated_outbound_ports = 1024
}

# Network Security Group rule for Load Balancer health probes
resource "azurerm_network_security_rule" "lb_health_probe" {
  name                        = "AllowLBHealthProbe"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}