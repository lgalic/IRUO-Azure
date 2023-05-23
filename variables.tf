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
    }
  ]
}

variable "WPice" {
  type = list(object({
    name = string
    size = string
  })) 
  default = [ {
    name = "WP-1"
    size = "B1ls"
  },
  {
    name = "WP-2"
    size = "B1ls"
  } ]
}