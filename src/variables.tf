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

// change it
variable "vnet" {
  default = {
    name          = "sonarqube"
    address_space = ["10.0.0.0/16"]
  }
}

//change it
variable "subnet_kafka" {
  default = {
    name          = "default"
    address_space = ["10.0.0.0/24"]
  }
}

variable "subnet_k8s" {
  default = {
    name          = "k8s"
    address_space = ["10.0.1.0/24"]
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

variable "kubernetes" {
  default = {
    name = "acqio-kafka-demo-k8s"
    dns_prefix = "acqiokafkak8s"
    kubernetes_version = "1.21.9"
    role_based_access_control_enabled = true
    sku_tier = "Paid"
    automatic_channel_upgrade = null
    default_node_pool = {
      name = "default"
      vm_size = "Standard_A2m_V2"
      enable_auto_scaling = false
      node_count = 3
      enable_host_encryption = false
      node_labels = { "node-type" = "system" }
      zones = [1,2,3]
    }
    network_profile = {
      network_plugin = "azure"
      network_policy = "calico"
      service_cidr  = "10.0.3.0/24"
      docker_bridge_cidr = "172.17.0.1/16"
    }
    auto_scaler_profile = {
      expander = "most-pods"
    }
    node_pools = {
      kafkaconnect = {
        name = "kafkaconnect"
        vm_size = "Standard_A2m_V2"
        enable_auto_scaling = true
        eviction_policy = "Delete"
        priority = "Spot"
        spot_max_price = -1
        mode = "User"
        node_labels = { 
          "node-type" = "kafkaconnect"
          "kubernetes.azure.com/scalesetpriority" = "spot"
        }
        node_taints = [
          "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
        ]
        zones = [1,2,3]
        node_count = 3
        min_count = 2
        max_count = 5
      }
    }
  }
}

variable "helm_nginx" {
  default = {
    name  = "nginx"
    repository  = "https://kubernetes.github.io/ingress-nginx"
    namespace = "nginx"
    chart = "ingress-nginx"
    version = "4.0.19"
    create_namespace = true
  }
}

variable "helm_kafka_ui" {
  default = {
    name  = "kafka-ui"
    repository  = "https://provectus.github.io/kafka-ui"
    namespace = "kafka"
    chart = "kafka-ui"
    version = "0.3.3"
    create_namespace = true
  }
}

variable "helm_strimzi_kafka" {
  default = {
    name  = "strimzi-kafka"
    repository  = "https://strimzi.io/charts/"
    namespace = "kafka"
    chart = "strimzi-kafka-operator"
    version = "0.19.0"
    create_namespace = true
  }
}

variable "tags" {
  type = map(string)
  default = {
    "environment" = "poc"
  }
}
