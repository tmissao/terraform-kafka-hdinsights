resource "azurerm_resource_group" "this" {
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = local.tags
}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account.name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_kind             = var.storage_account.account_kind
  account_tier             = var.storage_account.account_tier
  account_replication_type = var.storage_account.account_replication_type
  tags                     = local.tags
}

resource "azurerm_storage_container" "this" {
  name                  = var.storage_account_container.name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet.address_space
  tags                = local.tags
}

resource "azurerm_subnet" "subnet_kafka" {
  name                 = var.subnet_kafka.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_kafka.address_space
}

resource "azurerm_subnet" "subnet_k8s" {
  name                 = var.subnet_k8s.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_k8s.address_space
}

resource "random_password" "kafka_gateway" {
  length           = 16
  special          = true
  override_special = "_%@?"
}

resource "azurerm_hdinsight_kafka_cluster" "this" {
  name                          = var.kafka.name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  cluster_version               = var.kafka.cluster_hdinsight_version
  tier                          = var.kafka.tier
  tls_min_version               = "1.2"
  encryption_in_transit_enabled = true
  component_version {
    kafka = var.kafka.kafka_version
  }
  gateway {
    username = var.kafka.gateway.username
    password = random_password.kafka_gateway.result
  }
  storage_account {
    storage_container_id = azurerm_storage_container.this.id
    storage_account_key  = azurerm_storage_account.this.primary_access_key
    is_default           = true
  }
  roles {
    head_node {
      vm_size            = var.kafka.head_node.vm_size
      username           = var.kafka.username
      ssh_keys           = [file(var.kafka.ssh.public_key_path)]
      virtual_network_id = azurerm_virtual_network.this.id
      subnet_id          = azurerm_subnet.subnet_kafka.id
    }
    zookeeper_node {
      vm_size            = var.kafka.zookeeper_node.vm_size
      username           = var.kafka.username
      ssh_keys           = [file(var.kafka.ssh.public_key_path)]
      virtual_network_id = azurerm_virtual_network.this.id
      subnet_id          = azurerm_subnet.subnet_kafka.id
    }
    worker_node {
      vm_size                  = var.kafka.worker_node.vm_size
      username                 = var.kafka.username
      ssh_keys                 = [file(var.kafka.ssh.public_key_path)]
      virtual_network_id       = azurerm_virtual_network.this.id
      subnet_id                = azurerm_subnet.subnet_kafka.id
      number_of_disks_per_node = var.kafka.worker_node.number_of_disks_per_node
      target_instance_count    = var.kafka.worker_node.target_instance_count
    }
  }
  tags = local.tags
  lifecycle {
    ignore_changes = [cluster_version]
  }
}

resource "null_resource" "setup_kafka_server" {
  triggers = {
    variables = filebase64sha256("${path.module}/scripts/setup.sh")
  }
  connection {
    type        = "ssh"
    user        = var.kafka.username
    host        = azurerm_hdinsight_kafka_cluster.this.ssh_endpoint
    private_key = file(var.kafka.ssh.private_key_path)
  }
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup.sh"
  }
  depends_on = [azurerm_hdinsight_kafka_cluster.this]
}

data "external" "kafka_getinfo" {
  program = ["bash", "${path.module}/scripts/kafka-getinfo.sh"]
  query = {
    GATEWAY_USER         = var.kafka.gateway.username,
    GATEWAY_PASSWORD     = random_password.kafka_gateway.result,
    APPLICATION_ENDPOINT = azurerm_hdinsight_kafka_cluster.this.https_endpoint,
    CLUSTER_NAME         = azurerm_hdinsight_kafka_cluster.this.name
  }
  depends_on = [azurerm_hdinsight_kafka_cluster.this]
}

resource "null_resource" "configure_kafka_broker" {
  triggers = {
    kafkaconfigurescript = filebase64sha256("${path.module}/scripts/kafka-configure.sh")
    kafkaproperties      = filebase64sha256(var.kafka_configuration_file_path)
  }
  provisioner "local-exec" {
    command = "/bin/bash ${path.module}/scripts/kafka-configure.sh"
    environment = {
      GATEWAY_USER                          = var.kafka.gateway.username
      GATEWAY_PASSWORD                      = nonsensitive(random_password.kafka_gateway.result)
      APPLICATION_ENDPOINT                  = azurerm_hdinsight_kafka_cluster.this.https_endpoint
      CLUSTER_NAME                          = azurerm_hdinsight_kafka_cluster.this.name
      KAFKA_DESIRED_CONFIGURATION_FILE_PATH = var.kafka_configuration_file_path
    }
  }
  depends_on = [azurerm_hdinsight_kafka_cluster.this]
}

resource "null_resource" "create_kafka_topic" {
  for_each = var.kafka_topics
  triggers = {
    zookeepers     = data.external.kafka_getinfo.result.zookeepers
    topic          = each.key
    ssh_user       = var.kafka.username
    ssh_host       = azurerm_hdinsight_kafka_cluster.this.ssh_endpoint
    ssh_privatekey = sensitive(file(var.kafka.ssh.private_key_path))
  }
  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    host        = self.triggers.ssh_host
    private_key = self.triggers.ssh_privatekey
  }
  provisioner "remote-exec" {
    inline = [
      "/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper ${data.external.kafka_getinfo.result.zookeepers} --topic ${each.key} --partitions ${each.value.partitions} --replication-factor ${each.value.replication_factor} --if-not-exists"
    ]
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --delete --zookeeper ${self.triggers.zookeepers} --topic ${self.triggers.topic}"
    ]
  }
  depends_on = [azurerm_hdinsight_kafka_cluster.this, null_resource.configure_kafka_broker]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.kubernetes.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix = var.kubernetes.dns_prefix
  kubernetes_version = var.kubernetes.kubernetes_version
  sku_tier = var.kubernetes.sku_tier
  role_based_access_control_enabled = var.kubernetes.role_based_access_control_enabled
  automatic_channel_upgrade = var.kubernetes.automatic_channel_upgrade
  network_profile {
    network_plugin = var.kubernetes.network_profile.network_plugin
    network_policy = var.kubernetes.network_profile.network_policy
    service_cidr = var.kubernetes.network_profile.service_cidr
    dns_service_ip = cidrhost(var.kubernetes.network_profile.service_cidr, 10)
    docker_bridge_cidr = var.kubernetes.network_profile.docker_bridge_cidr
  }
  default_node_pool {
    name = var.kubernetes.default_node_pool.name
    vm_size = var.kubernetes.default_node_pool.vm_size
    enable_auto_scaling = var.kubernetes.default_node_pool.enable_auto_scaling
    node_count = var.kubernetes.default_node_pool.node_count
    enable_host_encryption = var.kubernetes.default_node_pool.enable_host_encryption
    node_labels = var.kubernetes.default_node_pool.node_labels
    vnet_subnet_id = azurerm_subnet.subnet_k8s.id
    zones = var.kubernetes.default_node_pool.zones
    tags = local.tags
  }
  auto_scaler_profile {
    expander = var.kubernetes.auto_scaler_profile.expander
  }
  identity {
    type = "SystemAssigned"
  }
  tags = local.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.kubernetes.node_pools
  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  enable_auto_scaling = each.value.enable_auto_scaling
  node_count = each.value.node_count
  min_count = each.value.min_count
  max_count = each.value.max_count
  eviction_policy = each.value.eviction_policy
  priority = each.value.priority
  mode = each.value.mode
  node_labels = each.value.node_labels
  node_taints = each.value.node_taints
  spot_max_price = each.value.priority == "Spot" ? each.value.spot_max_price : null
  vnet_subnet_id = azurerm_subnet.subnet_k8s.id
  zones = each.value.zones
  tags = local.tags
  lifecycle {
    ignore_changes = [ node_count ]
  }
}

resource "helm_release" "nginx" {
  name  = var.helm_nginx.name
  repository  = var.helm_nginx.repository
  namespace = var.helm_nginx.namespace
  chart = var.helm_nginx.chart
  version = var.helm_nginx.version
  create_namespace = var.helm_nginx.create_namespace
  values = [
    templatefile("${path.module}/templates/ingress-nginx-values.tpl", {
      NODE_TYPE = var.kubernetes.default_node_pool.node_labels.node-type
    })
  ]
}

resource "helm_release" "kafka_ui" {
  name  = var.helm_kafka_ui.name
  repository  = var.helm_kafka_ui.repository
  namespace = var.helm_kafka_ui.namespace
  chart = var.helm_kafka_ui.chart
  version = var.helm_kafka_ui.version
  create_namespace = var.helm_kafka_ui.create_namespace
  values = [
    templatefile("${path.module}/templates/kafka-ui-values.tpl", {
      INGRESS_PATH = "/kafka"
      INGRESS_CLASS_NAME = var.helm_nginx.name
      KAFKA_ZOOKEEPER_0 = split(",", data.external.kafka_getinfo.result.zookeepers)[0]
      KAFKA_BOOTSTRAP_0 = split(",", data.external.kafka_getinfo.result.brokers)[0]
      NODE_TYPE = var.kubernetes.default_node_pool.node_labels.node-type
    })
  ]
  depends_on = [ helm_release.nginx ]
}

resource "helm_release" "kafka_strimzi" {
  name  = var.helm_strimzi_kafka.name
  repository  = var.helm_strimzi_kafka.repository
  namespace = var.helm_strimzi_kafka.namespace
  chart = var.helm_strimzi_kafka.chart
  version = var.helm_strimzi_kafka.version
  create_namespace = var.helm_strimzi_kafka.create_namespace
}

resource "helm_release" "kafka_connect" {
  name  = "kafka-connect"
  namespace = "kafka"
  chart = "../artifacts/charts/kafka-connect"
  create_namespace = var.helm_strimzi_kafka.create_namespace
  values = [
    templatefile("${path.module}/templates/kafka-connect-values.tpl", {
      KAFKA_BOOTSTRAP_SERVERS = data.external.kafka_getinfo.result.brokers
      NODE_TYPE = var.kubernetes.default_node_pool.node_labels.node-type
    })
  ]
}