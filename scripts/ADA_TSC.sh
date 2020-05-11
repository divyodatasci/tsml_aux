#!/bin/bash

max_folds=30                                               
maxNumPending=150
queue="compute"
username="pfm15hbu"
mail="NONE"
mailto="pfm15hbu@uea.ac.uk"
max_memory=8000
max_time="168:00:00"
start_point=1
dataDir="/gpfs/home/pfm15hbu/scratch/TSCProblemsHCTSA/"
resultsDir="/gpfs/home/pfm15hbu/catch22/results3/"
outDir="/gpfs/home/pfm15hbu/catch22/output3/"
datasets="/gpfs/home/pfm15hbu/catch22/datasetsHCTSA.txt"
checkpoint="false"
jarFile="UEATSCcatch22.jar"
generateTrainFiles="false"

count=0
while read dataset; do
for classifier in RotF
do

numPending=$(squeue -u ${username} -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
while [ "${numPending}" -ge "${maxNumPending}" ]
do
    echo Waiting 30s, ${numPending} currently pending on ${queue}, user-defined max is ${maxNumPending}
	sleep 30
	numPending=$(squeue -u ${username} -r | awk '{print $5, $2}' | grep "PD ${queue}" | wc -l)
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
#SBATCH --array=1-${max_folds}
#SBATCH --mem=${max_memory}M
#SBATCH -o ${outDir}${classifier}/${dataset}/%A-%a.out
#SBATCH -e ${outDir}${classifier}/${dataset}/%A-%a.err

. /etc/profile

module add java/jdk1.8.0_231
java -Xmx${max_memory}m -jar /gpfs/home/${username}/${jarFile} -dp=${dataDir} -rp=${resultsDir} -gtf=${generateTrainFiles} -cn=${classifier} -dn=${dataset} -f=\$SLURM_ARRAY_TASK_ID -cp=${checkpoint}"  > generatedFile.sub

echo ${count} ${classifier}/${dataset}

sbatch < generatedFile.sub

fi

done
done < ${datasets}

echo Finished submitting jobs
