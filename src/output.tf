output "hdingisht_kafka_cluster" {
  sensitive = true
  value     = azurerm_hdinsight_kafka_cluster.this
}

output "kafka" {
  value = {
    zookeepers = data.external.kafka_getinfo.result.zookeepers
    brokers    = data.external.kafka_getinfo.result.brokers
  }
}

output "kubeconfig" {
  sensitive = true
  value = azurerm_kubernetes_cluster.this.kube_config_raw
}