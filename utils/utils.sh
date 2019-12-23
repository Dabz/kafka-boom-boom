#! /bin/sh
#
# utils.sh
# Copyright (C) 2018 gaspar_d </var/spool/mail/gaspar_d>
#
# Distributed under terms of the MIT license.
#

interface=eth0

##
## A note about our usage of docker
##
## We should be using docker-compose everywhere, but it is slow.
## We prefer relying directly on docker, thus the container to name translation with container_to_name
##
## Please note that we add -t as it is the default in docker-compose and we rely on tty


log() {
    echo -n '$> '

    echo "`echo $@ | tr '\r' '\n'`"
}

container_to_name() {
    container=$1
    echo "${PWD##*/}_${container}_1"
}

container_to_ip() {
    container=$1
    name=$(container_to_name $container)
    echo $(docker exec $name hostname -I)
}

block_host() {
    container=$1
    name=$(container_to_name $container)
    shift 1
    docker exec --privileged -t $name bash -c "tc qdisc add dev $interface root handle 1: prio" 2>&1
    docker exec --privileged -t $name bash -c "tc qdisc add dev $interface parent 1:1 handle 2: netem loss 100%" 2>&1
    for ip in $@; do
        docker exec --privileged -t $name bash -c "tc filter add dev $interface parent 1:0 protocol ip prio 1 u32 match ip dst $ip flowid 2:1" 2>&1
    done
}

remove_partition() {
    for container in $@; do
        name=$(container_to_name $container)
        docker exec --privileged -t $name bash -c "tc qdisc del dev $interface root" 2>&1 > /dev/null
    done
}

send_message() {
    container=$1
    name=$(container_to_name $container)
    shift 1
    msg=$@

    log "Sending messages to $container - $msg"
    docker exec -t $name bash -c "echo $msg | kafka-console-producer --broker-list localhost:9092 --topic test --sync --request-required-acks -1 --request-timeout-ms 10000"
    echo
}

send_message_to_topic() {
    container=$1
    name=$(container_to_name $container)
    shift 1
    topic=$1
    shift 1
    msg=$@

    log "Sending messages to $container - $msg"
    docker-compose exec -t $name bash -c "echo $msg | kafka-console-producer --broker-list localhost:9092 --topic $topic --sync --request-required-acks 1 --request-timeout-ms 10000"
    echo
}

read_messages() {
    container=$1
    name=$(container_to_name $container)
    number_of_messages_to_read=${2:-1}
    log "Reading $number_of_messages_to_read messages from $container:"
    docker exec -t $name timeout 15 kafka-console-consumer --bootstrap-server localhost:9092 --topic test --from-beginning --timeout-ms 10000 --max-messages $number_of_messages_to_read

    if [ ! $? -eq 0 ]; then
        log "Read unsuccessful"
    fi
}

get_state() {
    container=$1
    name=$(container_to_name $container)
    log "State for partition from $container"
    docker exec -t $name zookeeper-shell localhost:2181 get /brokers/topics/test/partitions/0/state | grep '{' | grep '}'
}

zookeeper_mode() {
    for container in $@; do
        name=$(container_to_name $container)
        mode=$(docker exec -t $name bash -c "echo stat | nc localhost 2181 | grep Mode")

        if [ $? -eq 0 ]; then
            log "$container $mode"
        else
            log "$container has no mode"
        fi
    done
}

create_topic() {
    container=$1
    name=$(container_to_name $container)
    shift 1
    topic=$1
    shift 1
    repl=$1
    shift 1
    min=$1

    log "Creating topic with min.isr=$min and replication factor $repl"
    log `docker exec -t $name kafka-topics --zookeeper localhost:2181 --create --topic $topic --replica-assignment $(seq $repl | xargs | tr ' ' ':') --config min.insync.replicas=$min`
}


