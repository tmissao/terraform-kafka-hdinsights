#!/bin/bash -eu

echo "#########################################################################################"
echo "#                       Stating Configuring KAFKA                                       #"
echo "#########################################################################################"

CREDENTIALS="$GATEWAY_USER:$GATEWAY_PASSWORD"
BASE_URL="https://$APPLICATION_ENDPOINT/api/v1/clusters/$CLUSTER_NAME"

echo "---> Getting latest tag of the broker configuration"
TAG=$(curl -sS -u "$CREDENTIALS" "$BASE_URL/configurations?type=kafka-broker" | jq -r '.items | sort_by(-.version) | .[0].tag')

echo "---> Getting latest broker configuration"
CURRENT_CONFIG=$(curl -sS -u "$CREDENTIALS" "$BASE_URL/configurations?type=kafka-broker&tag=$TAG" | jq --arg newtag $(echo version$(date +%s%N)) '.items[] | del(.href, .version, .Config) | .tag |= $newtag')

echo "---> Getting desired broker configuration"
DESIRED_CONFIG=$(jq '.' $KAFKA_DESIRED_CONFIGURATION_FILE_PATH)

echo "---> Merging broker configuration"
CONFIG=$(echo $CURRENT_CONFIG $DESIRED_CONFIG | jq -s '.[0] * .[1] | {"Clusters": {"desired_config": .}}')

echo "---> Updating broker configuration"
curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" -X PUT -d "$CONFIG" "$BASE_URL"

echo "---> Setting kafka server in maintanence mode"
curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" \
  -X PUT -d '{"RequestInfo": {"context": "turning on maintenance mode for Kafka"},"Body": {"ServiceInfo": {"maintenance_state":"ON"}}}' \
  "$BASE_URL/services/KAFKA"

echo "---> Stopping kafka server"
PAYLOAD=$(jq -n --arg CLUSTER_NAME "$CLUSTER_NAME" '{"RequestInfo":{"context":"_PARSE_.STOP.KAFKA","operation_level":{"level":"SERVICE","cluster_name": $CLUSTER_NAME,"service_name":"KAFKA"}},"Body":{"ServiceInfo":{"state":"INSTALLED"}}}')

echo "---> Waiting kafka server to stop"
STOP_RESPONSE=$(curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" -X PUT -d "$PAYLOAD" "$BASE_URL/services/KAFKA")
STOP_REQUEST_NUMBER=$(echo $STOP_RESPONSE | jq -r '.Requests.id') 

REQUEST_STATUS=''
while [[ "$REQUEST_STATUS" != "COMPLETED" ]]; do
  echo "---> Waiting kafka server to stop"
  sleep 5
  REQUEST_STATUS=$(curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" "$BASE_URL/requests/$STOP_REQUEST_NUMBER" | jq -r .Requests.request_status)
done

echo "---> Starting kafka server"
PAYLOAD=$(jq -n --arg CLUSTER_NAME "$CLUSTER_NAME" '{"RequestInfo":{"context":"_PARSE_.START.KAFKA","operation_level":{"level":"SERVICE","cluster_name": $CLUSTER_NAME,"service_name":"KAFKA"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}')
curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" -X PUT -d "$PAYLOAD" "$BASE_URL/services/KAFKA"

echo "---> Unsetting kafka server maintanence mode"
curl -sS -u "$CREDENTIALS" -H "X-Requested-By: ambari" -X PUT -d '{"RequestInfo": {"context": "turning off maintenance mode for KAFKA"},"Body": {"ServiceInfo": {"maintenance_state":"OFF"}}}' "$BASE_URL/services/KAFKA"

echo "#########################################################################################"
echo "#                       Finishing Configuring KAFKA                                     #"
echo "#########################################################################################"