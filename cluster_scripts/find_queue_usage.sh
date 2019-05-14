#! /bin/bash

XIFS=$IFS
IFS=' '
queues=( "$@" )
if [ ${#queues[@]} -eq 0 ]; then
	queues=( 'long-eth' )
	# user=$(whoami)
	# queues_str=$(bqueues -u $user | grep --invert QUEUE_NAME | awk '{print $1}')
	# read -r -a queues <<< "$queues_str"
fi
IFS='\n'
all_queue_stats=$(bqueues "$@")
# echo $all_queue_stats
bjobs_output=$(bjobs -noheader)

for queue in "${queues[@]}"; do

	# echo "$queue"

	queue_stats=$(echo "$all_queue_stats" | grep "$queue")
	queue_num_running_jobs=$(echo "$queue_stats" | awk '{print $10}')
	queue_num_pending_jobs=$(echo "$queue_stats" | awk '{print $9}')
	queue_max_num_jobs=$(echo "$queue_stats" | awk '{print $4}')
	user_max_num_jobs=$(echo "$queue_stats" | awk '{print $5}')
	queue_num_jobs=$(echo "$queue_stats" | awk '{print $8}')
	user_num_jobs=$(echo "$bjobs_output" | wc -l)

	# echo $queue_num_running_jobs $queue_num_pending_jobs $queue_max_num_jobs $user_max_num_jobs $queue_num_jobs $user_num_jobs

	overall_queue_usage=$(bc <<< "scale=2;$queue_num_running_jobs/$queue_max_num_jobs")
	user_queue_usage=$(bc <<< "scale=2;$user_num_jobs/$user_max_num_jobs")

	# echo $overall_queue_usage $user_queue_usage

	queue_usage=$(bc <<< "if ($user_queue_usage > $overall_queue_usage) $user_queue_usage else $overall_queue_usage")

	printf '%s %1.2f\n' "$queue" "$queue_usage"
done

IFS=$XIFS