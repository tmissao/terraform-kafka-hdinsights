locals {
  tags = merge(
    var.tags,
    {
      subscription   = data.azurerm_subscription.current.display_name
      resource_group = var.resource_group.name
    }
  )
}

data "azurerm_subscription" "current" {}

variable "resource_group" {
  type = object({
    name = string, location = string
  })
  default = {
    name     = "kafka-hdinsights-rg"
    location = "westus2"
  }
}

variable "storage_account" {
  default = {
    name                     = "kafkahdinsightsdemo"
    account_kind             = "StorageV2"
    account_tier             = "Standard"
    account_replication_type = "ZRS"
  }
}

variable "storage_account_container" {
  default = {
    name = "hdinsight"
  }
}

variable "vnet" {
  default = {
    name          = "sonarqube"
    address_space = ["10.0.0.0/16"]
  }
}

variable "subnet" {
  default = {
    name          = "default"
    address_space = ["10.0.0.0/24"]
  }
}

variable "kafka" {
  default = {
    name                      = "acqio-kafka-hdinsight-demo"
    tier                      = "Standard"
    cluster_hdinsight_version = "4.0"
    kafka_version             = "2.4"
    username                  = "azureadmin"
    ssh = {
      public_key_path  = "../keys/key.pub"
      private_key_path = "../keys/key"
    }
    gateway = {
      username = "azureadmin"
    }
    head_node = {
      vm_size = "Standard_E2a_V4"
    }
    zookeeper_node = {
      vm_size = "Standard_A2_V2"
    }
    worker_node = {
      vm_size                  = "Standard_E2a_V4"
      number_of_disks_per_node = 2
      target_instance_count    = 3
    }
  }
}

variable "kafka_configuration_file_path" {
  default = "./values/kafka-properties.json"
}

variable "kafka_topics" {
  default = {
    test1 = {
      replication_factor = 3
      partitions         = 3
    }
    test2 = {
      replication_factor = 2
      partitions         = 6
    }
    test3 = {
      replication_factor = 1
      partitions         = 1
    }
  }
}

variable "tags" {
  type = map(string)
  default = {
    "environment" = "poc"
  }
}
