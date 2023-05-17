terraform {
    backend "local" {
      path = "../1-ResGroup-PubIP/terraform.tfstate"
    }
}