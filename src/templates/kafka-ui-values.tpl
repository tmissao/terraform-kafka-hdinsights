envs:
  config:
    KAFKA_CLUSTERS_0_NAME: HDInsights
    KAFKA_CLUSTERS_0_ZOOKEEPER: ${KAFKA_ZOOKEEPER_0}
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: ${KAFKA_BOOTSTRAP_0}
    SERVER_SERVLET_CONTEXT_PATH: ${INGRESS_PATH}
ingress:
  enabled: true
  ingressClassName: nginx
  path: ${INGRESS_PATH}