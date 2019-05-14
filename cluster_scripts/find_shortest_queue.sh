#! /bin/bash

shortest_queue=$(bash find_queue_usage.sh | sort -k2 | head -n 1 | awk '{print $1}')
echo "$shortest_queue"