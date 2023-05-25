resource "azurerm_resource_group" "ime_prezime" {
    name = var.name
    location = "West Europe"
    lifecycle {
      prevent_destroy = true
    }
}

resource "azurerm_public_ip" "javna_IP" {
    name = "JavnaIPadresa"
    location = azurerm_resource_group.ime_prezime.location
    resource_group_name = azurerm_resource_group.ime_prezime.name
    allocation_method = "Static"
    depends_on = [ azurerm_resource_group.ime_prezime ]
    lifecycle {
      prevent_destroy = true
    }
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
  mreze_peer = merge({
    P=[{azurerm_virtual_network.priv-mreze[1].name = azurerm_virtual_network.priv-mreze[1].id,azurerm_virtual_network.priv-mreze[2].name = azurerm_virtual_network.priv-mreze[2].id}],
    D = [{azurerm_virtual_network.priv-mreze[0].name = azurerm_virtual_network.priv-mreze[0].id,azurerm_virtual_network.priv-mreze[2].name = azurerm_virtual_network.priv-mreze[2].id}],
    T = [{azurerm_virtual_network.priv-mreze[0].name = azurerm_virtual_network.priv-mreze[0].id,azurerm_virtual_network.priv-mreze[1].name = azurerm_virtual_network.priv-mreze[1].id}]
    })
}


resource "azurerm_virtual_network_peering" "Prva-all-peering" {
  count = length(local.mreze_peer["P"])
  name = "peering-to-${keys(local.mreze_peer["P"][count.index])}"
  resource_group_name = azurerm_resource_group.ime_prezime.name
  virtual_network_name = azurerm_virtual_network.priv-mreze[0].name
  remote_virtual_network_id = azurerm_virtual_network.priv-mreze[1].id
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit = false
}


/*
resource "azurerm_network_security_group" "internal" {
  name = "internal-sec"
  location = azurerm_resource_group.ime_prezime.location
  resource_group_name = azurerm_resource_group.ime_prezime.name

  security_rule {
    name = "${element(azurerm_virtual_network.priv-mreze[*].name, index(azurerm_virtual_network.priv-mreze[*].name, "PrvaMreza") )}-secrule"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    destination_port_range = "*"
    source_address_prefixes = [ element(local.priv_mreze_sub[*].address_prefix, index(local.priv_mreze_sub[*].address_prefix, "192.168.2.0/24")), element(local.priv_mreze_sub[*].address_prefix, index(local.priv_mreze_sub[*].address_prefix, "192.168.3.0/24")) ]
    destination_address_prefix = 
  }
}
*/
resource "azurerm_network_interface" "WP-NICs" {
    count = length(local.priv_mreze_sub)-1
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

resource "azurerm_network_interface" "Pub-NIC" {
  name = "Pub-NIC"
  location = element(azurerm_virtual_network.priv-mreze[*].location, length(azurerm_virtual_network.priv-mreze)-1)
  resource_group_name = azurerm_resource_group.ime_prezime.name
  ip_configuration {
    name = "Pub-NIC-ipconfig"
    subnet_id = element(local.priv_mreze_sub[*].id, length(local.priv_mreze_sub)-1)
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.javna_IP.id
  }
  depends_on = [ azurerm_virtual_network.priv-mreze, azurerm_public_ip.javna_IP ]
}


resource "azurerm_linux_virtual_machine" "WordPress" {
  count = length(var.WPice)
  name = var.WPice[count.index].name
  size = var.WPice[count.index].size
  resource_group_name = azurerm_resource_group.ime_prezime.name
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
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"
    version = "latest"
  }
#  custom_data = filebase64("cloud-init/wordpress-cloud-init.txt")
  depends_on = [ azurerm_network_interface.WP-NICs ]        
}

resource "azurerm_linux_virtual_machine" "Nginx-LB" {
  name = var.nginx_lb[0].name
  size = var.nginx_lb[0].size
  resource_group_name = azurerm_resource_group.ime_prezime.name
  location = azurerm_network_interface.Pub-NIC.location
  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [ azurerm_network_interface.Pub-NIC.id ]
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"
    version = "latest"
  }
#  custom_data = filebase64("cloud-init/wordpress-cloud-init.txt")
  depends_on = [ azurerm_network_interface.Pub-NIC ]        
}
