#!/usr/bin/env bash

set -o errexit

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[INFO] script_dir: $script_dir"

source "$HOME/development/erlang/installs/23.1.4/activate"

set -o nounset

readonly base_dir="$HOME/issues/rmq-generic-unix/rabbitmq_server-3.8.9"
readonly pid_base_dir="$base_dir/var/lib/rabbitmq/mnesia" # rabbit-1@shostakovich.pid
readonly rabbitmqctl_cmd="$base_dir/sbin/rabbitmqctl"
readonly rabbitmq_server_cmd="$base_dir/sbin/rabbitmq-server"

declare -i node_port_0=5671

for IDX in 1 2 3
do
    node_port="$((node_port_0 + IDX))"
    node_name="rabbit-$IDX"
    node_host_name="$node_name@shostakovich"
    pid_file="$pid_base_dir/$node_host_name.pid"
    LOG=debug RABBITMQ_NODENAME="$node_host_name" RABBITMQ_NODE_PORT="$node_port" \
        RABBITMQ_CONFIG_FILE="$script_dir/$node_name.conf" "$rabbitmq_server_cmd" > "$node_host_name-out.txt" 2>&1 &
    sleep 1
    "$rabbitmqctl_cmd" -n "$node_host_name" wait "$pid_file"
    "$rabbitmqctl_cmd" -n "$node_host_name" await_startup
done

for IDX in 2 3
do
    "$rabbitmqctl_cmd" -n "rabbit-$IDX@shostakovich" stop_app
    "$rabbitmqctl_cmd" -n "rabbit-$IDX@shostakovich" join_cluster 'rabbit-1@shostakovich'
    "$rabbitmqctl_cmd" -n "rabbit-$IDX@shostakovich" start_app
done

echo -n Declaring policy...
rabbitmqadmin declare policy name=ha pattern='.*' definition='{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic","queue-master-locator":"min-masters"}' priority=0 apply-to=queues
echo Done.

echo -n Declaring queues...
rabbitmqadmin --port 15672 declare queue name="test-1" durable=true
rabbitmqadmin --port 15673 declare queue name="test-2" durable=true
rabbitmqadmin --port 15674 declare queue name="test-3" durable=true
echo Done.

sleep 10

function declare_dynamic_shovel
{
    local -ri amqp_port="$1"
    local -ri http_api_port="$2"
    local -r src_queue="$3"
    local -r dest_queue="$4"
    local -r dynamic_shovel_name="move-$dest_queue"
    # rabbitmqadmin --port 15672 declare queue name="$dest_queue" durable=true
    curl -vu guest:guest -H 'content-type: application/json' \
        -X PUT "localhost:$http_api_port/api/parameters/shovel/%2F/$dynamic_shovel_name" \
        --data-binary "{\"component\":\"shovel\",\"vhost\":\"/\",\"name\":\"$dynamic_shovel_name\",\"value\":{\"src-uri\":\"amqp://localhost:$amqp_port/%2F\",\"src-queue\":\"$src_queue\",\"src-protocol\":\"amqp091\",\"src-prefetch-count\":1000,\"src-delete-after\":\"queue-length\",\"dest-protocol\":\"amqp091\",\"dest-uri\":\"amqp://localhost:$amqp_port/%2F\",\"dest-add-forward-headers\":false,\"ack-mode\":\"on-confirm\",\"dest-queue\":\"$dest_queue\"}}"
}

echo -n Declaring shovels...

for dest_queue in 'restart-1' 'restart-2'
do
    declare_dynamic_shovel 5672 15672 'test-1' "$dest_queue"
done

for dest_queue in 'restart-3' 'restart-4'
do
    declare_dynamic_shovel 5673 15673 'test-2' "$dest_queue"
done

for dest_queue in 'restart-5' 'restart-6'
do
    declare_dynamic_shovel 5674 15674 'test-3' "$dest_queue"
done

sleep 10

echo -n Deleting queues...
rabbitmqadmin --port 15672 delete queue name="restart-1"
rabbitmqadmin --port 15672 delete queue name="restart-2"
rabbitmqadmin --port 15673 delete queue name="restart-3"
rabbitmqadmin --port 15673 delete queue name="restart-4"
rabbitmqadmin --port 15674 delete queue name="restart-5"
rabbitmqadmin --port 15674 delete queue name="restart-6"
echo Done.

sleep 10

declare -i restart_node_idx=0
for restart_node_idx in 3 2
do
    restart_node_name="rabbit-$restart_node_idx"
    restart_node_port="$((5671 + restart_node_idx))"
    restart_node_host_name="$restart_node_name@shostakovich"

    "$rabbitmqctl_cmd" -n "$restart_node_name" shutdown

    restart_pid_file="$pid_base_dir/$restart_node_host_name.pid"
    LOG=debug RABBITMQ_NODENAME="$restart_node_host_name" RABBITMQ_NODE_PORT="$restart_node_port" \
        RABBITMQ_CONFIG_FILE="$script_dir/$restart_node_name.conf" "$rabbitmq_server_cmd" > "$restart_node_host_name-restart-out.txt" 2>&1 &
    sleep 1

    "$rabbitmqctl_cmd" -n "$restart_node_host_name" wait "$restart_pid_file"
    "$rabbitmqctl_cmd" -n "$restart_node_host_name" await_startup
done

echo '[INFO] access management UI on node 3 now!'
sleep 30

restart_node_idx=1
restart_node_name="rabbit-$restart_node_idx"
restart_node_port="$((5671 + restart_node_idx))"
restart_node_host_name="$restart_node_name@shostakovich"

"$rabbitmqctl_cmd" -n "$restart_node_name" shutdown

restart_pid_file="$pid_base_dir/$restart_node_host_name.pid"
LOG=debug RABBITMQ_NODENAME="$restart_node_host_name" RABBITMQ_NODE_PORT="$restart_node_port" \
    RABBITMQ_CONFIG_FILE="$script_dir/$restart_node_name.conf" "$rabbitmq_server_cmd" > "$restart_node_host_name-restart-out.txt" 2>&1 &
sleep 1

"$rabbitmqctl_cmd" -n "$restart_node_host_name" wait "$restart_pid_file"
"$rabbitmqctl_cmd" -n "$restart_node_host_name" await_startup
