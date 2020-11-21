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
