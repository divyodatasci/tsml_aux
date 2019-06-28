#! /bin/bash

# todo make java / python experiments class set 777 permissions
# todo make java use same args are python script

scripts_dir_name=scripts # folder where this script and siblings are located
classifier_names=( CEE ) # list of classifier names to run experiments on
dataset_names=() # list of dataset names to run experiments on; leave empty for population from file
dataset_name_list_file_path="/gpfs/home/vte14wgu/dataset_name_lists/test.txt" # path to file containing list of dataset names
queues=( sky-ib ) # list of queues to spread jobs over, set only 1 queue to submit all jobs to same queue
dynamic_queueing=false # set to true to find least busy queue for each job submission, otherwise round-robin iterate over queues
java_mem_in_mb=8000 # amount of memory for the jvm
job_mem_in_mb=$((java_mem_in_mb + 256)) # amount of memory for the lsf job
seed_ranges=( ) # list of seeds, e.g. ( "1-2" "4-5" ) for seeds 0, 1, 4, 5; leave empty for default 0-29
max_num_pending_jobs=200 # max number of pending jobs before waiting
verbosity=1 # verbosity; larger number == more printouts
sleep_time_on_pend=60s # time to sleep when waiting on pending jobs
estimate_train=true # whether to estimate train set; true or false
overwrite_results=false # whether to overwrite existing results; true or false
language=notjava # language of the script
datasets_dir_path=/gpfs/home/vte14wgu/Univariate2018 # path to folder containing datasets
results_dir_path=$(pwd)/results # path to results folder
script_file_path=$(pwd)/jar.jar # path to jar file
experiment_name=exp # experiment name to prepend job names
log_dir_path=$(pwd)/logs # path to log folder

# if dataset names are not predefined
if [ ${#dataset_names[@]} -eq 0 ]; then
	readarray -t dataset_names < $dataset_name_list_file_path # read the dataset names from file
fi

# # if seeds are not predefined
# if [ ${#seed_ranges[@]} -eq 0 ]; then
#     # populate with default 0 - 29
# 	seed_ranges=("1-30")
# fi
# if seeds are not predefined
if [ ${#seed_ranges[@]} -eq 0 ]; then
    # populate with default 0 - 29 in steps of 1, i.e. run all datasets through seed 0, then all datasets through seed 1, etc...
    for((i=1;i<=30;i++)); do
		seed_ranges+=("$i-$i")
    done
fi

# build the job script
job_template="
#! /bin/bash

classifier_name=\"%s\"
dataset_name=\"%s\"
log_seed=\"\$LSB_JOBINDEX\"
seed=\"\$((\$log_seed - 1))\"
"

if [ "$language" = 'python' ]; then
	# setup environment path to root project folder
	job_template="$job_template

export PYTHONPATH=$(pwd)

module add python/anaconda/2019.3/3.7

python"
elif [ "$language" = 'java' ]; then
	job_template="$job_template

module add java

java -Xms${java_mem_in_mb}M -Xmx${java_mem_in_mb}M -d64 -Dorg.slf4j.simpleLogger.deaultLogLevel=off -javaagent:/gpfs/home/vte14wgu/SizeOf.jar -jar"
else
	job_template="$job_template
echo"
fi

job_template="$job_template $script_file_path $datasets_dir_path \$classifier_name $results_dir_path \$dataset_name \$seed"

# if estimating train set
 if [ "$estimate_train" = 'true' ]; then
 	job_template="$job_template -t" # append arg
 fi

# if overwriting results
if [ "$overwrite_results" = 'true' ]; then
    job_template="$job_template -o" # append arg
fi

job_template="$job_template

job_log_dir_path="%s"
echo placeholder > \$job_log_dir_path/\$log_seed.err
echo placeholder > \$job_log_dir_path/\$log_seed.out
chmod 777 \$job_log_dir_path/\$log_seed.err
chmod 777 \$job_log_dir_path/\$log_seed.out
"

waitForFreeQueueSpace() {
    # if dynamic queueing
    if [ "$dynamic_queueing" = 'true' ]; then
        # set queue to most free queue
        queue=$(bash $scripts_dir_name/find_shortest_queue.sh "${queues[@]}")
    else
        # otherwise round-robin iterate over queues
        queue=${queues[0]}
        queues=( "${queues[@]:1}" )
        queues+=( $queue )
    fi
    # find number of pending jobs
    num_pending_jobs=$(2>&1 bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
    # while too many jobs pending
    while [ "${num_pending_jobs}" -ge "${max_num_pending_jobs}" ]
    do
        # too many pending jobs, wait a bit and try after
        echo $num_pending_jobs pending on $queue, more than $max_num_pending_jobs, will retry in $sleep_time_on_pend
        sleep ${sleep_time_on_pend}
        if [ "$dynamic_queueing" = 'true' ]; then
            queue=$(bash $scripts_dir_name/find_shortest_queue.sh "${queues[@]}")
        fi
        # find number of pending jobs
        num_pending_jobs=$(2>&1 bjobs | awk '{print $3, $4}' | grep "PEND ${queue}" | wc -l)
    done
}

# for each seed job
for seed_range in "${seed_ranges[@]}"; do
    # for each dataset job
    for dataset_name in "${dataset_names[@]}"; do
        # for each classifier
        for classifier_name in "${classifier_names[@]}"; do
            waitForFreeQueueSpace

            job_name="${experiment_name}_${classifier_name}_${dataset_name}_[$seed_range]"

			# make the log folder and set open permissions
			mkdir -p $log_dir_path
			chmod 777 $log_dir_path
			job_log_dir_path=$log_dir_path/$dataset_name
			# make the log folder and set open permissions
			mkdir -p $job_log_dir_path
			chmod 777 $job_log_dir_path

			job=$(printf "$job_template" "$classifier_name" "$dataset_name" "$job_log_dir_path")

			bsub -q $queue -oo "$job_log_dir_path/%I.out" -eo "$job_log_dir_path/%I.err" -R "rusage[mem=$job_mem_in_mb]" -J "$job_name" -M "$job_mem_in_mb" "$job"

        done
	done
done

