#!/usr/bin/env bash

set -o errexit
set -o nounset

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

set +o nounset
source "$HOME/development/erlang/installs/23.1.3/activate"
set -o nounset

readonly rmqctl="$HOME/development/rabbitmq/rabbitmq-server/sbin/rabbitmqctl"

"$rmqctl" -n 'rabbit-2' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-2@shostakovich" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5673" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/rabbit-2@shostakovich.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/mnesia/rabbit-2@shostakovich" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/mnesia/rabbit-2@shostakovich/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/mnesia/rabbit-2@shostakovich/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/feature_flags" RABBITMQ_PLUGINS_DIR="$HOME/development/rabbitmq/rabbitmq-server/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15673}] -rabbitmq_mqtt tcp_listeners [1884] -rabbitmq_stomp tcp_listeners [61614] -rabbitmq_prometheus tcp_config [{port,15693}] -rabbitmq_stream tcp_listeners [5556] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@shostakovich/enabled_plugins" "$HOME/development/rabbitmq/rabbitmq-server/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-2@shostakovich/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-2@shostakovich/log/startup_err &
"$rmqctl" -n 'rabbit-2' wait /tmp/rabbitmq-test-instances/rabbit-2@shostakovich/rabbit-2@shostakovich.pid
"$rmqctl" -n 'rabbit-2' await_startup

"$rmqctl" -n 'rabbit-3' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-3@shostakovich" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5674" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/rabbit-3@shostakovich.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/mnesia/rabbit-3@shostakovich" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/mnesia/rabbit-3@shostakovich/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/mnesia/rabbit-3@shostakovich/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/feature_flags" RABBITMQ_PLUGINS_DIR="$HOME/development/rabbitmq/rabbitmq-server/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15674}] -rabbitmq_mqtt tcp_listeners [1885] -rabbitmq_stomp tcp_listeners [61615] -rabbitmq_prometheus tcp_config [{port,15694}] -rabbitmq_stream tcp_listeners [5557] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@shostakovich/enabled_plugins" "$HOME/development/rabbitmq/rabbitmq-server/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-3@shostakovich/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-3@shostakovich/log/startup_err &
"$rmqctl" -n 'rabbit-3' wait /tmp/rabbitmq-test-instances/rabbit-3@shostakovich/rabbit-3@shostakovich.pid
"$rmqctl" -n 'rabbit-3' await_startup

echo '[INFO] access management UI on node 3 now!'
sleep 30

"$rmqctl" -n 'rabbit-1' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-1@shostakovich" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5672" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/rabbit-1@shostakovich.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/mnesia/rabbit-1@shostakovich" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/mnesia/rabbit-1@shostakovich/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/mnesia/rabbit-1@shostakovich/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/feature_flags" RABBITMQ_PLUGINS_DIR="$HOME/development/rabbitmq/rabbitmq-server/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15672}] -rabbitmq_mqtt tcp_listeners [1883] -rabbitmq_stomp tcp_listeners [61613] -rabbitmq_prometheus tcp_config [{port,15692}] -rabbitmq_stream tcp_listeners [5555]" RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/enabled_plugins" "$HOME/development/rabbitmq/rabbitmq-server/sbin/rabbitmq-server" > "/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/log/startup_log" 2> "/tmp/rabbitmq-test-instances/rabbit-1@shostakovich/log/startup_err" &
"$rmqctl" -n 'rabbit-1' wait /tmp/rabbitmq-test-instances/rabbit-1@shostakovich/rabbit-1@shostakovich.pid
"$rmqctl" -n 'rabbit-1' await_startup
