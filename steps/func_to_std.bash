#!/bin/bash

#SBATCH --job-name=func_to_std        #a convenient name for your job
#SBATCH --mem=600                     #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:05:00                #time limit (H:MM:SS)
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  FUNCTIONAL IMAGES TO STANDARD SPACE
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: [optional] remove extra ECM-specific steps to avoid confusion

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will register the funcitonal images to standard space.
#
# - Prerequisites: FSL tools enabled
# - Input: Subject (+session) ID
# - Output: Functional images in standard space
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2

#Check if script has already been completed
[ -f func/${FULLID_folder}/${FULLID_file}_preprocessed_func2std.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

echo "Transforming functional data to standard-space..."

#apply the previously computed registration parameters to the fMRI data
featregapply func/${FULLID_folder}/fmri.feat &&\

#Extra steps to allow voxel-wise ECM
#create a 4mm standard-space image (for voxel-wise ECM)
flirt -ref func/${FULLID_folder}/fmri.feat/reg/standard.nii.gz \
      -in func/${FULLID_folder}/fmri.feat/reg/standard.nii.gz \
      -out func/${FULLID_folder}/fmri.feat/reg/standard_4mm.nii.gz \
      -applyisoxfm 4 &&\

#register fMRI to standard space
applywarp --ref=func/${FULLID_folder}/fmri.feat/reg/standard_4mm.nii.gz \
          --in=func/${FULLID_folder}/${FULLID_file}_preprocessed_func.nii.gz \
          --out=func/${FULLID_folder}/${FULLID_file}_preprocessed_func2std.nii.gz \
          --warp=func/${FULLID_folder}/fmri.feat/reg/highres2standard_warp.nii.gz \
          --premat=func/${FULLID_folder}/fmri.feat/reg/example_func2highres.mat \
          --interp=trilinear &&\

printf "\n\n$(date)\n#### Done! ####\n"
