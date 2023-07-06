#!/bin/bash

#SBATCH --job-name=Atlas2Func         #a convenient name for your job
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
#updated: 03 04 2023
#status: still being developed
#to-do: add comments for individual steps

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
[ -f func/${FULLID_folder}/atlas/denoised_func_data_nonaggr_hptf_BNatlas_timeseries.txt ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n" 

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

#add epi mask to atlas
fslmaths func/${FULLID_folder}/atlas/${FULLID_file}_BNA_func.nii.gz \
         -mul func/${FULLID_folder}/nuisance/${FULLID_file}_minmask.nii.gz \
         func/${FULLID_folder}/atlas/${FULLID_file}_BNA_func_min.nii.gz &&\

####create timeseries with atlas label####
echo "  Creating timeseries per atlas region..." &&\

fslmeants -i func/${FULLID_folder}/${FULLID_file}_preprocessed_func.nii.gz \
          --label=func/${FULLID_folder}/atlas/${FULLID_file}_BNA_func_min.nii.gz \
          -o func/${FULLID_folder}/atlas/${FULLID_file}_BNA_timeseries.txt &&\

#create symbolic link with easier-to-find filename
ln -s atlas/${FULLID_file}_BNA_timeseries.txt \
      func/${FULLID_folder}/${FULLID_file}_BNA_timeseries.txt &&\

printf "\n#### Done! ####\n"
