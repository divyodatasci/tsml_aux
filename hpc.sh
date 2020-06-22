 #! /bin/bash

# ---------- config ----------
name="pf_gtf"
dir="$(dirname $0)"
version="_v9"
resultsDir="${dir}/results${version}"
user="$(whoami)"
jar="${dir}/tsml${version}.jar"
space="home"
logsDir="${dir}/logs${version}/${user}"
datasetsDir="/gpfs/${space}/${user}/datasets/uni2018"
datasetNames=() # "Ham") # leave empty for population from file
datasetNameList="/gpfs/${space}/${user}/datasets/lists/2015.txt"
folds=() # leave empty for default 1-30 seeds
for((i=1;i<=30;i++)); do
	folds+=( $i )
done
classifierNames=("clsfA" "clsfB" "clsfC")
mem="8000" # must be in mb
foldsByDatasets='true' # true --> run fold 0 over all datasets, then fold 1, etc. false --> run all folds over dataset 1, then all folds over dataset 2, etc.
queue="long-eth"
threads="1"
args="-gtf=true -cp=false" # -l=ALL"
maxNumPendingJobs=50
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

numJobs=${#datasetNames[@]}
jobArraySize=${#folds[@]}
if [ "$foldsByDatasets" = 'true' ]; then
	numJobs=${#folds[@]}
	jobArraySize=${#datasetNames[@]}
fi

echo "datasets: ${datasetNames[@]}"
echo "folds: ${folds[@]}"
echo "numJobs: $numJobs"
echo "jobArraySize: $jobArraySize"

# for each classifier
for((i=0;i<$numJobs;i++)); do

	# for each dataset
	for classifierName in "${classifierNames[@]}"; do

		numPendingJobs=$(bjobs --noheader | grep PEND | wc -l)
		while [ "${numPendingJobs}" -ge "${maxNumPendingJobs}" ]
		do
			echo "${name}${version} $maxNumPendingJobs pending jobs, waiting 30s"
			sleep 30s
			numPendingJobs=$(bjobs --noheader | grep PEND | wc -l)
		done
		

		jobName="${name}${version}_${classifierName}_${datasetNames[$i]}"
		logDir="${logsDir}/${classifierName}/${datasetNames[$i]}"
		logFileName="fold%I"
		indices="
			foldIndex=\"\$((LSB_JOBINDEX-1))\"
			datasetNameIndex=\"$i\"
			"
		if [ "$foldsByDatasets" = 'true' ]; then
			indices="
				foldIndex=\"$i\"
				datasetNameIndex=\"\$((LSB_JOBINDEX-1))\"
				"
			jobName="${name}${version}_${classifierName}_fold${folds[$i]}"
			logDir="${logsDir}/${classifierName}/fold${folds[$i]}"
			logFileName="dataset%I"
		fi

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

			module add java/jdk1.8.0_201

			java -XX:+UseSerialGC -Xms${mem}M -Xmx${mem}M -jar \"$jar\" -dp=\"$datasetsDir\" -dn=\"\$datasetName\" -rp=\"$resultsDir\" -cn=\"$classifierName\" -f=\"\$fold\" -mem=\"$mem\" -threads=\"$threads\" $args

			"

		# echo "$job"

		echo "$job" | bsub -q "$queue" -J "${jobName}[1-${jobArraySize}]" -oo "${logDir}/${logFileName}.out" -eo "${logDir}/${logFileName}.err" -R "rusage[mem=$(($mem+128))]"

	done
done
