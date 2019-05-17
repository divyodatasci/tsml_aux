#! /bin/bash

XIFS=$IFS
IFS=' '

working_dir_path=$(pwd)

shortest_queue=$(bash $(dirname $0)/find_queue_usage.sh "$@" | sort -k2 | head -n 1 | awk '{print $1}')
echo "$shortest_queue"

IFS=$XIFS