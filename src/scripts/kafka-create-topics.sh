#!/bin/bash -eu

/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper "${ZOOKEEPER}" --topic "${TOPIC_NAME}"