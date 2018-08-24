# Boom Boom Kafka!! 

This project is an attempt to simulate network partition within a Kafka cluster and observe the behavior of the cluster.
The purpose is to evaluate the durability guarantees provided by a Kafka cluster in case of unreliable network.
Those scenarios try to emulate a Kafka stretch cluster over 2 datacenters.

## Most interesting results 

* Kafka can operate properly without Zookeeper as long as there is no need to change the ISR
  - The ISR update fails without Zookeeper and thus producer using _acks=all_ would be blocked by _out of sync_ members 
- It's possible to have multiple leaders for a single partition in case of network partition, but:
  - Only one leader can accept write with _acks=all
  - Using _acks=1_ could lead to data getting truncated
- To ensure durability of messages:
  - _acks_ must be set to _all_, otherwise you might write to an _invalid_ leader
  - _min.insync.replicas_ must be set up to ensure that data is replicated on all desired physical location
- If Zookeeper quorum is rebuild, there is actually no guarantee that the new quorum have all the latest data:
  - this could results in data loss or in messages getting duplicated inside leaders 
	- it's probably better to rely on hierarchical quorum to avoid those issues

## Scenarios

### Scenario 1 

3 Kafka brokers: kafka-1, kafka-2 and kafka-3 and one zookeeper. 
Current leader is currently on kafka-1 then kafka-1 block all incoming messages from kafka-2, kafka-3 and zookeeper

### Scenario 2

4 Kafka brokers: kafka-1, kafka-2, kafka-3 and kafka-4 and one zookeeper. 
Current leader is currently on kafka-1 then a network partition is simulated:
- on one side kafka-1, kafka-2 and kafka-3
- on another side kafka-4 and zookeeper 

### Scenario 3

4 Kafka brokers: kafka-1, kafka-2, kafka-3 and kafka-4 and 3 zookeeper. 
For some reasons, you decide to rebuild the quorum of zookeeper (e.g. you lost a rack or a DC). 
There is no guarantee, after rebuilding a quorum, that the nodes have all the required information. 
