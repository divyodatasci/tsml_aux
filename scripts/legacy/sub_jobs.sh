#! /bin/bash

# WARNING: not built for spaces in strings (i.e. file paths, string variables, etc). This will explode if you do that.

# todo make java / python experiments class set 777 permissions
# todo spaces support (low priority)
# todo make java use same args are python script
# todo comment up this script

scripts_dir_name=scripts

classifier_names=(PF)
dataset_names=() # leave empty for population from file
dataset_names_file_path=dataset_name_lists/pf_problematic.txt
queues=(sky-eth sky-ib)
dynamic_queueing=true # set to true to find least busy queue for each job submission
mem_in_mb=4000
resample_seeds=() # leave empty for default 1-30 resamples
max_num_pending_jobs=100
verbosity=1
sleep_time_on_pend=60
estimate_train=false
overwrite_results=true
resamples_by_datasets=false # n = number of datasets, r = num resamples. true gives r array jobs with n elements, false gives n array jobs with r elements
language=python
working_dir_path=$(pwd)
datasets_dir_path="/gpfs/home/vte14wgu/datasets"
results_dir_path="${working_dir_path}/results"
script_file_path="${working_dir_path}/sktime/contrib/experiments.py"
experiment_name=pf_v1
log_dir_path="${working_dir_path}/logs"

if [ ${#dataset_names[@]} -eq 0 ]; then
	readarray -t dataset_names < $dataset_names_file_path
fi

if [ ${#resample_seeds[@]} -eq 0 ]; then
	resample_seeds=()
	for((i=0;i<30;i++)); do
		resample_seeds+=( $i )
	done
fi

num_jobs=${#dataset_names[@]}
job_array_size=${#resample_seeds[@]}
if [ "$resamples_by_datasets" = 'true' ]; then
	num_jobs=${#resample_seeds[@]}
	job_array_size=${#dataset_names[@]}
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

XIFS=$IFS
IFS=' '

job_template="
#! /bin/bash

dataset_names=(${dataset_names[@]})
resample_seeds=(${resample_seeds[@]})

classifier_name=%s"

if [ "$resamples_by_datasets" = 'true' ]; then
	label=resample
	job_template="$job_template
dataset_name_index=\$((\$LSB_JOBINDEX-1))
resample_seed_index=%s"	
else
	label=dataset
	job_template="$job_template
dataset_name_index=%s
resample_seed_index=\$((\$LSB_JOBINDEX-1))"
fi


job_template="$job_template

dataset_name=\${dataset_names[\$dataset_name_index]}
resample_seed=\${resample_seeds[\$resample_seed_index]}

"

if [ "$language" = 'python' ]; then
	# setup environment path to root project folder
	job_template="$job_template

export PYTHONPATH=$working_dir_path

module add python/anaconda/2019.3/3.7

python"
elif [ "$language" = 'java' ]; then
	job_template="$job_template

module add java

java -jar"
else
	job_template="$job_template
echo"
fi

job_template="$job_template $script_file_path $datasets_dir_path \$dataset_name \$classifier_name $experiment_results_dir_path \$resample_seed -v $verbosity"

if [ "$estimate_train" = 'true' ]; then
	job_template="$job_template --estimate_train"
fi

if [ "$overwrite_results" = 'true' ]; then
	job_template="$job_template --overwrite_results"
fi

job_template="$job_template

run_log_dir_path=%s

echo placeholder > \$run_log_dir_path/$label\$LSB_JOBINDEX.err
echo placeholder > \$run_log_dir_path/$label\$LSB_JOBINDEX.out
chmod 777 \$run_log_dir_path/$label\$LSB_JOBINDEX.err
chmod 777 \$run_log_dir_path/$label\$LSB_JOBINDEX.out

"

count=0
for classifier_name in "${classifier_names[@]}"; do

	for((i=0;i<$num_jobs;i++)); do

		if [ "$dynamic_queueing" = 'true' ]; then
			queue=$(bash $scripts_dir_name/find_shortest_queue.sh "${queues[@]}")
		else
			queue=${queues[0]}
			queues=( "${queues[@]:1}" )
			queues+=( $queue )
		fi

		num_pending_jobs=$(2>&1 bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
		while [ "${num_pending_jobs}" -ge "${max_num_pending_jobs}" ]
		do
			if [ "${num_pending_jobs}" -ge "${max_num_pending_jobs}" ]; then
				echo $num_pending_jobs pending on $queue, more than $max_num_pending_jobs, will retry in $sleep_time_on_pend
				sleep ${sleep_time_on_pend}
				if [ "$dynamic_queueing" = 'true' ]; then
					queue=$(bash $scripts_dir_name/find_shortest_queue.sh "${queues[@]}")
				fi
			fi
			num_pending_jobs=$(2>&1 bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
		done

		job_name="${dataset_names[$i]}"
		if [ "$resamples_by_datasets" = 'true' ]; then
			job_name="${resample_seeds[$i]}"
		fi

		chmod 777 $experiment_log_dir_path
		mkdir -p $experiment_log_dir_path/$classifier_name
		chmod 777 $experiment_log_dir_path/$classifier_name
		run_log_dir_path=$experiment_log_dir_path/$classifier_name/$job_name
		mkdir -p $run_log_dir_path
		chmod 777 $run_log_dir_path

		job=$(printf "$job_template" "$classifier_name" "$i" "$run_log_dir_path")
	
		bsub -q $queue -oo "$run_log_dir_path/$label%I.out" -eo "$run_log_dir_path/$label%I.err" -R \"rusage[mem=$mem_in_mb]\" -J "${experiment_name}_${classifier_name}_${job_name}[1-$job_array_size]" -M $mem_in_mb "$job" 

	done
done

IFS=$XIFS