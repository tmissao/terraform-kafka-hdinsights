
## Kafka Commands
---

- `create topic`
```bash
bin/kafka-topics.sh --create --zookeeper <zookepper> --topic <topic-name> --partitions <int> --replication-factor <int> --if-not-exists
```

- `list topics`
```bash
bin/kafka-topics.sh --list --zookeeper <zookepper>
```

- `describe topic`
```bash
bin/kafka-topics.sh --describe --zookeeper <zookepper> --topic <topic-name>
```

- `get topic config`
```bash
bin/kafka-configs.sh --zookeeper <zookeeper> --entity-type topics --entity-name <topic-name> --describe
```

- `get topic number of messages`
```bash
bin/kafka-run-class.sh kafka.tools.GetOffsetShell --topic <topic-name> --broker-list <broker>
```

- `delete topic`
```bash
bin/kafka-topics.sh --delete --zookeeper <zookepper> --topic <topic-name>"
```

- `create a console producer without key`
```bash
bin/kafka-console-producer.sh --broker-list <broker> --topic <topic-name>
```

- `create a console producer with key`
```bash
bin/kafka-console-producer.sh --broker-list <broker> --topic <topic-name> --property parse.key=true --property key.separator='='
```

- `create a console consumer`
```bash
bin/kafka-console-consumer.sh --bootstrap-server <broker> --topic <topic-name> --from-beginning --property parse.key=true --property key.separator=
```

## References
---

https://strimzi.io/docs/operators/latest/configuring.html#assembly-kafka-connect-str
https://dzone.com/articles/kafka-connect-on-kubernetes-the-easy-way
https://strimzi.io/docs/operators/latest/configuring.html#assembly-kafka-connect-str