#!/bin/csh

echo script started

max_folds=1                                               
maxNumPending=150
queue="compute"
username="cjr13geu"
mail="NONE"
mailto="cjr13geu@uea.ac.uk"
max_memory=8000
max_time="168:00:00"
start_point=1
dataDir="/gpfs/home/cjr13geu/datasets/ts/univariate/"
resultsDir="/gpfs/home/cjr13geu/results/python/"
outDir="/gpfs/home/cjr13geu/output/python/"
datasets="/gpfs/home/cjr13geu/problems/test.txt"
checkpoint="false"
pythonFile="sktime/sktime/contrib/experiments.py"
generateTrainFiles="false"

echo vars assigned

count=0
while read dataset; do
for classifier in pt
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

echo num jobs check completed

echo "#!/bin/csh

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
python /gpfs/home/${username}/python/${pythonFile} ${dataDir} ${resultsDir} ${classifier} ${dataset} \$SLURM_ARRAY_TASK_ID ${checkpoint}"  > python.sub

echo sub file created
echo ${count} ${classifier}/${dataset}

sbatch < python.sub

fi

done
done < ${datasets}

echo Finished submitting jobs