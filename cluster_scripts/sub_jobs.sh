#! /bin/bash

# todo seeds precedence
# todo java version

classifier_names=('PF')
dataset_names=() # leave empty for population from file
dataset_names_file_path='dataset_names.txt'
queue='long-eth'
dynamic_queueing='false' # set to true to find least busy queue for each job submission
mem_in_mb=4000
resamples=() # leave empty for default 1-30 resamples
max_num_pending_jobs=100
sleep_time_on_pend=60
produce_train_estimate='True'
overwrite_results='False'

working_dir_path=$(pwd)
datasets_dir_path="${working_dir_path}/datasets"
results_dir_path="${working_dir_path}/results"
script_file_path="${working_dir_path}/sktime/contrib/experiments.py"
experiment_name='sktime_pf'
log_dir_path="${working_dir_path}/logs"

if [ -z "$queue" ]; then
	queue=$(bash find_shortest_queue.sh)
fi

if [ ${#dataset_names[@]} -eq 0 ]: then
	readarray -t dataset_names < $dataset_names_file_path
fi

if [ ${#resamples[@]} -eq 0 ]: then
	resamples=( '1-30' )
fi

mkdir -p $log_dir_path
chmod 777 $log_dir_path
mkdir -p $results_dir_path
chmod 777 $results_dir_path
experiment_log_dir_path="$log_dir_path/$experiment_name"
mkdir -p $experiment_log_dir_path
chmod 777 $experiment_log_dir_path
experiment_results_dir_path="$results_dir_path/$experiment_name"
mkdir -p $experiment_results_dir_path
chmod 777 $experiment_results_dir_path

for classifier_name in "${classifier_names[@]}"; do

	classifier_log_dir_path="$experiment_log_dir_path/$classifier_name/$dataset_name"
	mkdir -p $classifier_log_dir_path
	chmod -R 777 $classifier_log_dir_path

	for dataset_name in "${dataset_names[@]}"; do
		if [ "$dynamic_queueing" = 'true' ]; do
			queue=$(bash find_shortest_queue.sh)
		done
		num_pending_jobs=$(bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
		while [ "${num_pending_jobs}" -ge "${max_num_pending_jobs}" ]
		do
			if [ "${num_pending_jobs}" -ge "${max_num_pending_jobs}" ]; then
				echo $num_pending_jobs pending on $queue, more than $max_num_pending_jobs, will retry in $sleep_time
				sleep ${sleep_time}
				if [ "$dynamic_queueing" = 'true' ]; do
					queue=$(bash find_shortest_queue.sh)
				done
			fi
			num_pending_jobs=$(bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
		done

		run_log_dir_path="$classifier_log_dir_path/$dataset_name"
		mkdir -p $run_log_dir_path
		chmod -R 777 $run_log_dir_path

		bsub_job="#! /bin/bash

module add python/anaconda/2019.3/3.7

# setup environment path to root project folder
export PYTHONPATH=$working_dir_path

python $script_file_path $datasets_dir_path/ $experiment_results_dir_path/ $classifier_name $dataset_name \$((\$LSB_JOBINDEX-1)) $produce_train_estimate

chmod -R 777 $experiment_results_dir_path
"
		# echo $bsub_job

		bsub -q $queue -oo "$run_log_dir_path/%I.out" -eo "$run_log_dir_path/%I.err" -R \"rusage[mem=$mem_in_mb]\" -J "${experiment_name}_${classifier_name}_${dataset_name}[1-$num_resamples]" -M $mem_in_mb "$bsub_job" 

	done
done
