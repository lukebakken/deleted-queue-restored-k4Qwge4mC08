#!/usr/bin/env bash

set -o errexit
set -o nounset

echo -n Deleting queues...
rabbitmqadmin --port 15672 delete queue name="restart-1"
rabbitmqadmin --port 15672 delete queue name="restart-2"
rabbitmqadmin --port 15673 delete queue name="restart-3"
rabbitmqadmin --port 15673 delete queue name="restart-4"
rabbitmqadmin --port 15674 delete queue name="restart-5"
rabbitmqadmin --port 15674 delete queue name="restart-6"
echo Done.
