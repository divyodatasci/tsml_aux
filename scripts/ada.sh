 #! /bin/bash

# ---------- config ----------
name="pf" # experiment name (appears as job name on cluster)
dir="$(dirname $0)" # current dir
version="_v9" # appended to results dir / log dir name and job names
resultsDir="${dir}/results${version}" # where the results go
user=$(whoami) # the user to run jobs as
jar="${dir}/tsml${version}.jar" # path to the jar
space="home" # home / scratch space
logsDir="${dir}/logs${version}/${user}" # where to log to
datasetsDir="/gpfs/${space}/${user}/datasets/uni2018" # where the data is
datasetNames=() # "Ham") # leave empty for population from file
datasetNameList="/gpfs/${space}/${user}/datasets/lists/2015.txt" # location of the lists of dataset names
folds=() # array of folds to run
for((i=1;i<=30;i++)); do # populate folds 1-30
	folds+=( $i )
done
classifierNames=("clsfA" "clsfB" "clsfC") # list of classifier names
mem="8000" # must be in mb
foldsByDatasets='true' # true --> run fold 0 over all datasets, then fold 1, etc. false --> run all folds over dataset 1, then all folds over dataset 2, etc.
queue="compute" # the queue
threads="1" # how many threads to use
mailType="END,FAIL" # email me when job ends or fails
mailUser="${user}@uea.ac.uk" # my email address
args="-gtf=false -cp=false" #  -l=ALL" # parameters to be passed to the Experiments class
maxTime="168:00:00" # max time for a job to run in hrs:mins:secs
maxNumPendingJobs=50 # max number of pending jobs before waiting
# ---------- end config ----------

# check the jar exists
if [ ! -f "$jar" ]; then
    echo "jar not found: $jar"
fi

# check the datasets dir exists
if [ ! -d "$datasetsDir" ]; then
    echo "datasets dir not found: $datasetsDir"
fi

umask=000 # allow everyone to access files created by this script

# if datasets are not explicitly listed
if [ ${#datasetNames[@]} -eq 0 ]; then
	# check dataset list exists
	if [ ! -f "$datasetNameList" ]; then
	    echo "dataset name list not found: $datasetNameList"
	fi
	readarray -t datasetNames < "$datasetNameList"
fi

# variables for doing datasets by folds or folds by datasets
numJobs=${#datasetNames[@]}
jobArraySize=${#folds[@]}
if [ "$foldsByDatasets" = 'true' ]; then
	numJobs=${#folds[@]}
	jobArraySize=${#datasetNames[@]}
fi

# a few stats
echo "datasets: ${datasetNames[@]}"
echo "folds: ${folds[@]}"
echo "numJobs: $numJobs"
echo "jobArraySize: $jobArraySize"

# for each dataset / fold
for((i=0;i<$numJobs;i++)); do
	
	# for each classifier
	for classifierName in "${classifierNames[@]}"; do

		# wait for queue to clear
		numPendingJobs=$(squeue -h --user="$user" -r --state=PD | wc -l)
		while [ "${numPendingJobs}" -ge "${maxNumPendingJobs}" ]
		do
			echo "${name}${version} $maxNumPendingJobs pending jobs, waiting 30s"
			sleep 30s
			numPendingJobs=$(squeue -h --user="$user" -r --state=PD | wc -l)
		done
		
		# work out the job size depending on folds by datasets or datasets by folds
		jobName="${name}${version}_${classifierName}_${datasetNames[$i]}"
		logDir="${logsDir}/${classifierName}/${datasetNames[$i]}"
		logFileName="fold%a"
		indices="
			foldIndex=\"\$((SLURM_ARRAY_TASK_ID-1))\"
			datasetNameIndex=\"$i\"
			"
		if [ "$foldsByDatasets" = 'true' ]; then
			indices="
				foldIndex=\"$i\"
				datasetNameIndex=\"\$((SLURM_ARRAY_TASK_ID-1))\"
				"
			jobName="${name}${version}_${classifierName}_fold${folds[$i]}"
			logDir="${logsDir}/${classifierName}/fold${folds[$i]}"
			logFileName="dataset%a"
		fi

		# make the log dir if not already
		mkdir -p "$logDir"

		job="#! /bin/bash

			umask=000 # allow everyone to access files created by this script

			[ -f /etc/profile ] && source /etc/profile # source the global profile config
			[ -f ~/.profile ] && source ~/.profile # source your user profile config

			datasetNames=( ${datasetNames[@]} )
			folds=( ${folds[@]} )

			$indices
			
			datasetName=\"\${datasetNames[\$datasetNameIndex]}\"
			fold=\"\${folds[\$foldIndex]}\"

			echo \"dataset: \$datasetName\"
			echo \"fold: \$fold\"
			echo \"running java...\"

			module add java/jdk1.8.0_231 # load java

			java -XX:+UseSerialGC -Xms${mem}M -Xmx${mem}M -jar \"$jar\" -dp=\"$datasetsDir\" -dn=\"\$datasetName\" -rp=\"$resultsDir\" -cn=\"$classifierName\" -f=\"\$fold\" -mem=\"$mem\" -threads=\"$threads\" $args

			"

		# echo "$job"

		id=$(echo "$job" | sbatch --job-name="$jobName" --output="${logDir}/${logFileName}.out" --error="${logDir}/${logFileName}.err" --mail-type="NONE" --mail-user="$mailUser" --cpus-per-task="$threads" --mem="$(($mem+128))" --array="1-$jobArraySize" --parsable --time="$maxTime")

		echo "Submitted batch job $id"

	done

done
