#!/usr/bin/env bash

set -o errexit
set -o nounset

# NOTE:
# Start your cluster using a command like this:
# cd $HOME/development/rabbitmq/rabbitmq-server
# git clean -fxd
# make FULL=1 dist
# make RABBITMQ_CONFIG_FILE="$HOME/issues/misc/rabbitmq.conf" PLUGINS='rabbitmq_management rabbitmq_top rabbitmq_shovel rabbitmq_shovel_management' LOG=debug NODES=3 start-cluster

declare -r _hostname="$HOSTNAME"
declare -r perf_test_base_dir="$HOME/development/rabbitmq/rabbitmq-perf-test"
declare -r rmq_base_dir="$HOME/development/rabbitmq/rabbitmq-server"
declare -r rmqctl="$rmq_base_dir/sbin/rabbitmqctl"

function setup_erlang
{
    if ! hash erl 2>/dev/null
    then
        set +o nounset
        source "$HOME/development/erlang/installs/23.2.1/activate"
        set -o nounset
    fi
}

setup_erlang

echo -n Declaring queues...
rabbitmqadmin --port 15672 declare queue name="test-1" durable=true
rabbitmqadmin --port 15673 declare queue name="test-2" durable=true
rabbitmqadmin --port 15674 declare queue name="test-3" durable=true
echo Done.

sleep '2'

function publish_messages
{
    local -ri message_count=32768

    local -ri amqp_port="$1"
    local -r queue="$2"
    (
        cd "$perf_test_base_dir"
        mvn exec:java -Dexec.mainClass='com.rabbitmq.perf.PerfTest' -Dexec.args="--uri amqp://localhost:$amqp_port --predeclared --queue $queue --confirm 8 --pmessages $message_count --producers 1 --consumers 0"
    )
}

function declare_dynamic_shovel
{
    local -ri amqp_port="$1"
    local -ri http_api_port="$2"
    local -r src_queue="$3"
    local -r dest_queue="$4"
    local -r dynamic_shovel_name="move-$dest_queue"

    # local -r src_delete_after='"queue-length"'
    local -r src_delete_after='1024'

    # local -r src_uri='["amqp://localhost:5672/%2F","amqp://localhost:5673/%2F","amqp://localhost:5674/%2F"]'
    # local -r dest_uri='["amqp://localhost:5672/%2F","amqp://localhost:5673/%2F","amqp://localhost:5674/%2F"]'
    local -r src_uri="\"amqp://localhost:$amqp_port/%2F\""
    local -r dest_uri="\"amqp://localhost:$amqp_port/%2F\""

    curl -vu guest:guest -H 'content-type: application/json' \
        -X PUT "localhost:$http_api_port/api/parameters/shovel/%2F/$dynamic_shovel_name" \
        --data-binary "{\"component\":\"shovel\",\"vhost\":\"/\",\"name\":\"$dynamic_shovel_name\",\"value\":{\"src-uri\":"$src_uri",\"src-queue\":\"$src_queue\",\"src-protocol\":\"amqp091\",\"src-prefetch-count\":1000,\"src-delete-after\":$src_delete_after,\"dest-protocol\":\"amqp091\",\"dest-uri\":"$dest_uri",\"dest-add-forward-headers\":false,\"ack-mode\":\"on-confirm\",\"dest-queue\":\"$dest_queue\"}}"
}

echo -n Publishing messages...
publish_messages 5672 'test-1' &
publish_messages 5673 'test-2' &
publish_messages 5674 'test-3' &
wait
echo Done.

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

sleep 5

echo -n Deleting queues...
rabbitmqadmin --port 15672 delete queue name="restart-1"
rabbitmqadmin --port 15672 delete queue name="restart-2"
rabbitmqadmin --port 15673 delete queue name="restart-3"
rabbitmqadmin --port 15673 delete queue name="restart-4"
rabbitmqadmin --port 15674 delete queue name="restart-5"
rabbitmqadmin --port 15674 delete queue name="restart-6"
echo Done.

# echo CHECK FOR STALE DYNAMIC SHOVEL DATA
# exit 0

sleep 5

"$rmqctl" -n 'rabbit-2' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-2@$_hostname" RABBITMQ_CONFIG_FILE="$HOME/issues/misc/rabbitmq.conf" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5673" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/rabbit-2@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15673}] -rabbitmq_mqtt tcp_listeners [1884] -rabbitmq_stomp tcp_listeners [61614] -rabbitmq_prometheus tcp_config [{port,15693}] -rabbitmq_stream tcp_listeners [5556] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log/startup_err &
"$rmqctl" -n 'rabbit-2' wait /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/rabbit-2@$_hostname.pid
"$rmqctl" -n 'rabbit-2' await_startup

# echo CHECK FOR STALE DYNAMIC SHOVEL DATA
# exit 0

"$rmqctl" -n 'rabbit-3' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-3@$_hostname" RABBITMQ_CONFIG_FILE="$HOME/issues/misc/rabbitmq.conf" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5674" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/rabbit-3@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15674}] -rabbitmq_mqtt tcp_listeners [1885] -rabbitmq_stomp tcp_listeners [61615] -rabbitmq_prometheus tcp_config [{port,15694}] -rabbitmq_stream tcp_listeners [5557] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log/startup_err &
"$rmqctl" -n 'rabbit-3' wait /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/rabbit-3@$_hostname.pid
"$rmqctl" -n 'rabbit-3' await_startup

# echo '[INFO] access management UI on node 3 now!'
# sleep 10

"$rmqctl" -n 'rabbit-1' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-1@$_hostname" RABBITMQ_CONFIG_FILE="$HOME/issues/misc/rabbitmq.conf" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5672" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/rabbit-1@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15672}] -rabbitmq_mqtt tcp_listeners [1883] -rabbitmq_stomp tcp_listeners [61613] -rabbitmq_prometheus tcp_config [{port,15692}] -rabbitmq_stream tcp_listeners [5555]" RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log/startup_log" 2> "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log/startup_err" &
"$rmqctl" -n 'rabbit-1' wait "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/rabbit-1@$_hostname.pid"
"$rmqctl" -n 'rabbit-1' await_startup

echo CHECK FOR STALE DYNAMIC SHOVEL DATA
