data "terraform_remote_state" "ResGroup_PubIP" {
  backend = "local"
  config = {
    path="${path.module}/../1-ResGroup-PubIP/terraform.tfstate"
  }
}  

resource "azurerm_virtual_network" "priv-mreze" {
    count = length(var.priv_mreze)
    name = var.priv_mreze[count.index].name
    location = var.priv_mreze[count.index].location
    resource_group_name = data.terraform_remote_state.ResGroup_PubIP.outputs.res-group-name
    address_space = var.priv_mreze[count.index].address_space
    subnet {
        name = var.priv_mreze[count.index].subnet.name
        address_prefix = var.priv_mreze[count.index].subnet.address_prefix
    }
}

resource "azurerm_network_interface" "WP-NICs" {
    count = length(var.WPice)
    name = "NIC-${count.index}"
    location = var.priv_mreze[count.index].location
    resource_group_name = data.terraform_remote_state.ResGroup_PubIP.outputs.res-group-name
    ip_configuration {
      name = "NIC-${count.index}-ipconfig"
      subnet_id = azurerm_virtual_network.priv-mreze[index(azurerm_virtual_network.priv-mreze.*.subnet, var.priv_mreze[count.index].subnet.name)]
      private_ip_address_allocation = "Dynamic"
    }
    depends_on = [ azurerm_virtual_network.priv-mreze ]
}

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