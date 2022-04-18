#!/bin/bash -eux

read input

eval "$(echo $input | jq -r '@sh "GATEWAY_USER=\(.GATEWAY_USER)"')"
eval "$(echo $input | jq -r '@sh "GATEWAY_PASSWORD=\(.GATEWAY_PASSWORD)"')"
eval "$(echo $input | jq -r '@sh "APPLICATION_ENDPOINT=\(.APPLICATION_ENDPOINT)"')"
eval "$(echo $input | jq -r '@sh "CLUSTER_NAME=\(.CLUSTER_NAME)"')"

ZOOKEEPERS=$(curl -sS -u $GATEWAY_USER:$GATEWAY_PASSWORD -G https://$APPLICATION_ENDPOINT/api/v1/clusters/$CLUSTER_NAME/services/ZOOKEEPER/components/ZOOKEEPER_SERVER | jq -r '["\(.host_components[].HostRoles.host_name):2181"] | join(",")')
BROKERS=$(curl -sS -u $GATEWAY_USER:$GATEWAY_PASSWORD -G https://$APPLICATION_ENDPOINT/api/v1/clusters/$CLUSTER_NAME/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name):9092"] | join(",")';)

jq -n \
  --arg ZOOKEEPERS "$ZOOKEEPERS" \
  --arg BROKERS "$BROKERS" \
  '{"zookeepers": $ZOOKEEPERS, "brokers": $BROKERS}'
