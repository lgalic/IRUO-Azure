variable "client_id" {
    type = string
}

variable "client_secret" {
    type = string
}

variable "tenant_id" {
    type = string
}

variable "subscription_id" {
    type = string
}

variable "name" {
    type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type = string
}

variable "priv_mreze" {
    type = list(object({
        name = string
        location = string
        address_space = list(string)
        subnet = object({
          name = string
          address_prefix = string
        })
    }))
    default = [ {
      name = "PrvaMreza"
      location = "West Europe"
      address_space = [ "192.168.1.0/24" ]
      subnet = {
        name = "subnet1"
        address_prefix = "192.168.1.0/24"
      }
    },
    {
      name = "DrugaMreza"
      location = "North Europe"
      address_space = [ "192.168.2.0/24" ]
      subnet = {
        name = "subnet1"
        address_prefix = "192.168.2.0/24"
      }
    },
    {
      name = "TrecaMreza"
      location = "Germany West Central"
      address_space = [ "192.168.3.0/24" ]
      subnet = {
        name = "subnet1"
        address_prefix = "192.168.3.0/24"
      }
    }
  ]
}

variable net_peering {
  
}

variable "WPice" {
  type = list(object({
    name = string
    size = string
  })) 
  default = [ {
    name = "WP-1"
    size = "Standard_B1ls"
  },
  {
    name = "WP-2"
    size = "Standard_B1ls"
  } ]
}

variable "nginx_lb" {
  type = list(object({
    name = string
    size = string
  }))
  default = [ {
    name = "Nginx-lb"
    size = "Standard_B1ls"
  } ]
}