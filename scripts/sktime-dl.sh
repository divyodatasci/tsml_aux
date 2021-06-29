#! /bin/csh

echo script started

start_point=0
end_point=4                                              
maxNumPending=150
queue="gpu-rtx6000-2"
qos="gpu"
username="cjr13geu"
mail="NONE"
mailto="cjr13geu@uea.ac.uk"
max_memory=120G
max_time="168:00:00"
seed=1

dataDir="/gpfs/home/cjr13geu/datasets/ts/univariate/"
resultsDir="/gpfs/home/cjr13geu/results/python/"
outDir="/gpfs/home/cjr13geu/output/python/"
datasets="/gpfs/home/cjr13geu/problems/Custom.txt"
checkpoint="false"
pythonFile="/gpfs/home/cjr13geu/reps/sktime-dl/sktime_dl/experimental/reproductions.py"
setSeed="true"
classifier="inception"

echo vars assigned

count=0
while read dataset; do

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

echo num jobs check completed

echo "#!/bin/csh

#SBATCH --mail-type=${mail}   
#SBATCH --mail-user=${mailto}
#SBATCH -p ${queue}
#SBATCH --qos=${qos}
#SBATCH -t ${max_time}
#SBATCH --gres=gpu:1
#SBATCH --job-name=${classifier}${dataset}
#SBATCH --array=${start_point}-${end_point}
#SBATCH --mem=${max_memory}M
#SBATCH -o ${outDir}${classifier}/${dataset}/%A-%a.out
#SBATCH -e ${outDir}${classifier}/${dataset}/%A-%a.err

. /etc/profile
module load cuda/10.2.89
python ${pythonFile} ${dataDir} ${resultsDir} ${classifier} ${dataset} ${seed} ${setSeed} \$SLURM_ARRAY_TASK_ID"  > python.sub

echo sub file created
echo ${count} ${classifier}/${dataset}

sbatch < python.sub

fi

done < ${datasets}

echo Finished submitting jobs