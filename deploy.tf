resource "azurerm_resource_group" "ime_prezime" {
    name = var.name
    location = "West Europe"
}

resource "azurerm_virtual_network" "priv_mreze"{
    count = length(var.priv_mreze)
    name = var.priv_mreze[count.index].name
    location = var.priv_mreze[count.index].location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    address_space = var.priv_mreze[count.index].address_space
    subnet {
        name = var.priv_mreze[count.index].subnet.name
        address_prefix = var.priv_mreze[count.index].subnet.address_prefix
    }
    depends_on = [ azurerm_resource_group.ime_prezime ]
}

resource "azurerm_network_interface" "WP-NICs" {
    count = length(var.WPice)
    name = "NIC-${count.index}"
    location = azurerm_resource_group.ime_prezime.location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    ip_configuration {
      name = "NIC-${count.index}-ipconfig"
      subnet_id = azurerm_virtual_network.priv_mreze[count.index].subnet.id
      private_ip_address_allocation = "Dynamic"
    }
    depends_on = [ azurerm_virtual_network.priv_mreze ]
}

resource "azurerm_linux_virtual_machine" "WordPress" {
  count = length(var.WPice)
  name = var.WPice[count.index].name
  size = var.WPice[count.index].size
  resource_group_name = azurerm_resource_group.ime_prezime.name
  location = azurerm_resource_group.ime_prezime.location
  admin_username = var.admin_username
  admin_password = var.admin_password
  network_interface_ids = [ azurerm_network_interface.WP-NICs[count.index].id ]
  storage_profile {
    source_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "22.04-LTS"
        version = "latest"
    }
  }
  custom_data = filebase64("cloud-init/wordpress-cloud-init.txt")
  depends_on = [ azurerm_network_interface.WP-NICs ]        
}

resource "azurerm_public_ip" "javna_IP" {
    name = "JavnaIPadresa"
    location = azurerm_resource_group.ime_prezime.location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    allocation_method = "Static"
    depends_on = [ azurerm_resource_group.ime_prezime ]
}

resource "azurerm_application_gateway" "L7-lb" {
    name = "App-Gateway-WP"
    location = azurerm_resource_group.ime_prezime.location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    gateway_ip_configuration {
      name = azurerm_public_ip.javna_IP.name
      public_ip_address_id = azurerm_public_ip.javna_IP.id
    }
    frontend_port {
      name = "HTTPS-frontend"
      port = 443
    }
    frontend_ip_configuration {
      name = "frontend-ipconfig"
      public_ip_address_id = azurerm_public_ip.javna_IP.id
    }
    #kreirati VM-ice prvo
    backend_address_pool {
      name = "backend-pool-1"
    }
}