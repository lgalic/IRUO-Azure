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

  P = {
      (azurerm_virtual_network.priv-mreze[1].name) = azurerm_virtual_network.priv-mreze[1].id, 
      (azurerm_virtual_network.priv-mreze[2].name) = azurerm_virtual_network.priv-mreze[2].id
    }
  D = {
      (azurerm_virtual_network.priv-mreze[0].name) = azurerm_virtual_network.priv-mreze[0].id, 
      (azurerm_virtual_network.priv-mreze[2].name) = azurerm_virtual_network.priv-mreze[2].id
    }
  T = {
      (azurerm_virtual_network.priv-mreze[0].name) = azurerm_virtual_network.priv-mreze[0].id, 
      (azurerm_virtual_network.priv-mreze[1].name) = azurerm_virtual_network.priv-mreze[1].id
      }
}


resource "azurerm_virtual_network_peering" "Prva-all-peering" {
  for_each = local.P
  name = "peering-to-${each.key}"
  resource_group_name = azurerm_resource_group.ime_prezime.name
  virtual_network_name = azurerm_virtual_network.priv-mreze[0].name
  remote_virtual_network_id = each.value
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit = false
  depends_on = [azurerm_virtual_network.priv-mreze]
}

resource "azurerm_virtual_network_peering" "Druga-all-peering" {
  for_each = local.D
  name = "peering-to-${each.key}"
  resource_group_name = azurerm_resource_group.ime_prezime.name
  virtual_network_name = azurerm_virtual_network.priv-mreze[1].name
  remote_virtual_network_id = each.value
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit = false
  depends_on = [azurerm_virtual_network.priv-mreze]
}

resource "azurerm_virtual_network_peering" "Trece-all-peering" {
  for_each = local.T
  name = "peering-to-${each.key}"
  resource_group_name = azurerm_resource_group.ime_prezime.name
  virtual_network_name = azurerm_virtual_network.priv-mreze[2].name
  remote_virtual_network_id = each.value
  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit = false
  depends_on = [azurerm_virtual_network.priv-mreze]
}


resource "azurerm_network_security_group" "public-sec" {
  name = "pub-sec"
  location = azurerm_resource_group.ime_prezime.location
  resource_group_name = azurerm_resource_group.ime_prezime.name

  security_rule {
    name = "ssh"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    destination_port_range = "22"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name = "https"
    priority = 101
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    destination_port_range = "443"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
  }
}



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
  location = azurerm_resource_group.ime_prezime.location
  resource_group_name = azurerm_resource_group.ime_prezime.name
  ip_configuration {
    name = "Pub-NIC-ipconfig"
    subnet_id = element(local.priv_mreze_sub[*].id, length(local.priv_mreze_sub)-1)
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.javna_IP.id
  }
  depends_on = [ azurerm_virtual_network.priv-mreze, azurerm_public_ip.javna_IP ]
}

resource "azurerm_network_interface_security_group_association" "Pub-NIC-secgroup" {
  network_interface_id = azurerm_network_interface.Pub-NIC.id
  network_security_group_id = azurerm_network_security_group.public-sec.id
  depends_on = [ azurerm_network_interface.Pub-NIC, azurerm_network_security_group.public-sec ]
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

data "template_file" "nginx-lb-init" {
  template = "${file("${path.module}/cloud-init/nginx-lb-cloud-init.yml")}"

  vars = {
    public_IP = "${azurerm_public_ip.javna_IP.ip_address}"
    wp1 = "${azurerm_linux_virtual_machine.WordPress[0].name}"
    wp2 = "${azurerm_linux_virtual_machine.WordPress[1].name}"
    wp1_address = "${azurerm_network_interface.WP-NICs[0].private_ip_address}"
    wp2_address = "${azurerm_network_interface.WP-NICs[1].private_ip_address}"
  }
  depends_on = [ 
    azurerm_public_ip.javna_IP, 
    azurerm_linux_virtual_machine.WordPress,
    azurerm_network_interface.WP-NICs
   ]
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
  custom_data = <<-EOT
#cloud-config
package_upgrade: true
packages:
    - haproxy

runcmd:
  - |
    cat >> /etc/haproxy/haproxy.cfg << EOF

    frontend https-in
      bind ${azurerm_public_ip.javna_IP.ip_address}:443
      backend wp-servers
      option forward

    backend wp-servers
      balance roundrobin
      server ${azurerm_linux_virtual_machine.WordPress[0].name} ${azurerm_network_interface.WP-NICs[0].private_ip_address}:80 check
      server ${azurerm_linux_virtual_machine.WordPress[1].name} ${azurerm_network_interface.WP-NICs[1].private_ip_address}:80 check
    EOF

    systemctl enable haproxy --now
  EOT
  depends_on = [ azurerm_network_interface.Pub-NIC ]        
}
