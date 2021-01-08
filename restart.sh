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

"$rmqctl" -n 'rabbit-2' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-2@$_hostname" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5673" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/rabbit-2@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/mnesia/rabbit-2@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15673}] -rabbitmq_mqtt tcp_listeners [1884] -rabbitmq_stomp tcp_listeners [61614] -rabbitmq_prometheus tcp_config [{port,15693}] -rabbitmq_stream tcp_listeners [5556] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-2@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/log/startup_err &
"$rmqctl" -n 'rabbit-2' wait /tmp/rabbitmq-test-instances/rabbit-2@$_hostname/rabbit-2@$_hostname.pid
"$rmqctl" -n 'rabbit-2' await_startup

"$rmqctl" -n 'rabbit-3' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-3@$_hostname" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5674" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/rabbit-3@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/mnesia/rabbit-3@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15674}] -rabbitmq_mqtt tcp_listeners [1885] -rabbitmq_stomp tcp_listeners [61615] -rabbitmq_prometheus tcp_config [{port,15694}] -rabbitmq_stream tcp_listeners [5557] " RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-3@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log/startup_log 2> /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/log/startup_err &
"$rmqctl" -n 'rabbit-3' wait /tmp/rabbitmq-test-instances/rabbit-3@$_hostname/rabbit-3@$_hostname.pid
"$rmqctl" -n 'rabbit-3' await_startup

"$rmqctl" -n 'rabbit-1' shutdown
ERL_LIBS="" RABBITMQ_NODENAME="rabbit-1@$_hostname" RABBITMQ_NODE_IP_ADDRESS="" RABBITMQ_NODE_PORT="5672" RABBITMQ_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname" RABBITMQ_PID_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/rabbit-1@$_hostname.pid" RABBITMQ_LOG_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log" RABBITMQ_MNESIA_BASE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia" RABBITMQ_MNESIA_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname" RABBITMQ_QUORUM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname/quorum" RABBITMQ_STREAM_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/mnesia/rabbit-1@$_hostname/stream" RABBITMQ_FEATURE_FLAGS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/feature_flags" RABBITMQ_PLUGINS_DIR="$rmq_base_dir/plugins" RABBITMQ_PLUGINS_EXPAND_DIR="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/plugins" RABBITMQ_SERVER_START_ARGS="-ra wal_sync_method sync -rabbit loopback_users [] -rabbitmq_management listener [{port,15672}] -rabbitmq_mqtt tcp_listeners [1883] -rabbitmq_stomp tcp_listeners [61613] -rabbitmq_prometheus tcp_config [{port,15692}] -rabbitmq_stream tcp_listeners [5555]" RABBITMQ_ENABLED_PLUGINS="ALL" RABBITMQ_ENABLED_PLUGINS_FILE="/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/enabled_plugins" "$rmq_base_dir/sbin/rabbitmq-server" > "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log/startup_log" 2> "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/log/startup_err" &
"$rmqctl" -n 'rabbit-1' wait "/tmp/rabbitmq-test-instances/rabbit-1@$_hostname/rabbit-1@$_hostname.pid"
"$rmqctl" -n 'rabbit-1' await_startup

echo CHECK FOR STALE DYNAMIC SHOVEL DATA
