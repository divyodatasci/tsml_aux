#!/bin/bash

max_folds=30 
start_fold=1                                                
maxNumSubmitted=800
queue="compute-16-64"
username="pfm15hbu"
mail="NONE"
mailto="pfm15hbu@uea.ac.uk"
max_memory=8000
max_time="168:00:00"
start_point=1
dataDir="/gpfs/home/pfm15hbu/scratch/TSCProblems2018/"
resultsDir="/gpfs/home/pfm15hbu/DictionaryBased/results/"
outDir="/gpfs/home/pfm15hbu/DictionaryBased/output/"
datasets="/gpfs/home/pfm15hbu/DictionaryBased/datasetsBespoke.txt"
jarFile="UEATSCr.jar"
generateTrainFiles="true"

count=0
while read dataset; do
for classifier in ROCKET
do

numPending=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
numRunning=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "R ${queue}" | wc -l)
while [ "$((numPending+numRunning))" -ge "${maxNumSubmitted}" ]
do
    echo Waiting 30s, $((numPending+numRunning)) currently submitted on ${queue}, user-defined max is ${maxNumSubmitted}
	sleep 30
	numPending=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
	numRunning=$(squeue -u ${username} --format="%10i %15P %20j %10u %10t %10M %10D %20R" -r | awk '{print $5, $2}' | grep "R ${queue}" | wc -l)
done

((count++))

if ((count>=start_point)); then

mkdir -p ${outDir}${classifier}/${dataset}/

echo "#!/bin/bash

#SBATCH --mail-type=${mail}   
#SBATCH --mail-user=${mailto}
#SBATCH -p ${queue}
#SBATCH -t ${max_time}
#SBATCH --job-name=${classifier}${dataset}
#SBATCH --array=${start_fold}-${max_folds}
#SBATCH --mem=${max_memory}M
#SBATCH -o ${outDir}${classifier}/${dataset}/%A-%a.out
#SBATCH -e ${outDir}${classifier}/${dataset}/%A-%a.err

. /etc/profile

module add java/jdk1.8.0_231
OMP_NUM_THREADS=1 java -XX:+UseSerialGC -Xmx${max_memory}m -jar /gpfs/home/${username}/${jarFile} -dp=${dataDir} -rp=${resultsDir} -gtf=${generateTrainFiles} -cn=${classifier} -dn=${dataset} -f=\$SLURM_ARRAY_TASK_ID"  > generatedFile.sub

echo ${count} ${classifier}/${dataset}

sbatch < generatedFile.sub --qos=ht

fi

done
done < ${datasets}

echo Finished submitting jobs