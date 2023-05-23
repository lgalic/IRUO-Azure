resource "azurerm_resource_group" "ime_prezime" {
    name = var.name
    location = "West Europe"
}

resource "azurerm_public_ip" "javna_IP" {
    name = "JavnaIPadresa"
    location = azurerm_resource_group.ime_prezime.location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    allocation_method = "Static"
    depends_on = [ azurerm_resource_group.ime_prezime ]
}

resource "azurerm_virtual_network" "priv-mreze" {
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

locals {
  priv_mreze_sub = flatten(azurerm_virtual_network.priv-mreze[*].subnet)
}

output "test" {
  value = [for d in local.priv_mreze_sub : d.address_prefix ]
}


resource "azurerm_network_interface" "WP-NICs" {
    count = length(local.priv_mreze_sub)
    name = "NIC-${azurerm_virtual_network.priv-mreze[count.index].location}"
    location = azurerm_virtual_network.priv-mreze[count.index].location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    ip_configuration {
      name = "NIC-${azurerm_virtual_network.priv-mreze[count.index].location}-ipconfig"
      subnet_id = local.priv_mreze_sub[count.index].id
      private_ip_address_allocation = "Dynamic"
    }
    depends_on = [ azurerm_virtual_network.priv-mreze ]
}

/*
resource "azurerm_linux_virtual_machine" "WordPress" {
  count = length(var.WPice)
  name = var.WPice[count.index].name
  size = var.WPice[count.index].size
  resource_group_name = data.terraform_remote_state.ResGroup_PubIP.outputs.res-group-name
  location = azurerm_network_interface.WP-NICs[count.index].location
  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [ azurerm_network_interface.WP-NICs[count.index].id ]
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "22.04-LTS"
    version = "latest"
  }
#  custom_data = filebase64("cloud-init/wordpress-cloud-init.txt")
  depends_on = [ azurerm_network_interface.WP-NICs ]        
}
*/

/*resource "azurerm_application_gateway" "L7-lb" {
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
}*/