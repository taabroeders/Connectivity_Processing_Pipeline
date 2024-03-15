#!/bin/bash

#SBATCH --job-name=atlas_func         #a convenient name for your job
#SBATCH --mem=3                       #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	  #max CPU cores per process
#SBATCH --time=0:05:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      CREATE TIMESERIES
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: [optional] add compatibility with other atlasses

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will register the atlas the funcitonal images and create regional timeseries.
#
# - Prerequisites: FSL tools enabled
# - Input: Subject (+session) ID
# - Output: A timeseries text file
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2

#Check if script has already been completed
[ -f func/${FULLID_folder}/${FULLID_file}_BNA_timeseries.txt ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p func/${FULLID_folder}/atlas &&\

####tranform atlas to functional space####
echo "Extracting Brainnetome atlas timeseries..." &&\
echo "  Tranforming atlas to functional space..." &&\

#transform to fmri
flirt -in anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz \
      -applyxfm \
      -init func/${FULLID_folder}/fmri.feat/reg/highres2example_func.mat \
      -ref func/${FULLID_folder}/fmri.feat/example_func.nii.gz \
      -out func/${FULLID_folder}/atlas/${FULLID_file}_BNA_func.nii.gz \
      -interp nearestneighbour &&\

####create timeseries and connectivity matrix with atlas label####
echo "  Creating timeseries per atlas region..." &&\

fslmeants -i func/${FULLID_folder}/${FULLID_file}_preprocessed_func.nii.gz \
          --label=func/${FULLID_folder}/atlas/${FULLID_file}_BNA_func.nii.gz \
          -o func/${FULLID_folder}/atlas/${FULLID_file}_BNA_timeseries.txt &&\

eval "$(conda shell.bash hook)" &&\
conda activate ${FILEDIR}/preproc_env_ica &&\
${FILEDIR}/preproc_env_ica/bin/python -c "import pandas as pd;df = pd.read_csv('func/${FULLID_folder}/atlas/${FULLID_file}_BNA_timeseries.txt', sep='  ', decimal=',', engine='python');print(df.corr().to_string(index=False, header=False))" >> func/${FULLID_folder}/atlas/${FULLID_file}_BNA_connectivity.txt &&\
conda deactivate &&\

#create symbolic link with easier-to-find filename
ln -s atlas/${FULLID_file}_BNA_timeseries.txt \
      func/${FULLID_folder}/${FULLID_file}_BNA_timeseries.txt &&\

printf "\n\n$(date)\n#### Done! ####\n"