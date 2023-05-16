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

output "res-group-name" {
  value = azurerm_resource_group.ime_prezime.name
}

output "res-group-location" {
    value = azurerm_resource_group.ime_prezime.location
}

output "pub-IP-id" {
  value = azurerm_public_ip.javna_IP.id
}