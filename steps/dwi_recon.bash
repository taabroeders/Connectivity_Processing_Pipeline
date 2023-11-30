#!/bin/bash

#SBATCH --job-name=dwi_recon          #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2       	  #max CPU cores per process
#SBATCH --time=00:10:00               #time limit (HH:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  		DWI tensor reconstruction
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do:

#Review History
#Reviewed by Ismail Koubiyr (25 04 2023)

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform reconstruciton of the diffusion images.
#
# - Prerequisites: 
# - Input: Bids-style input directory, pipeline folder and the subject (+session) ID & preprocessed anat data
# - Output: Reconstructed diffusion images
#----------------------------------------------------------------------

#Input variables
INPUT_DIR=$(realpath $1)
FULLID_file=$2
FULLID_folder=$3

dwi_nii=${INPUT_DIR}/dwi/${FULLID_file}*_dwi.nii.gz
dwi_bval=${dwi_nii%%.nii.gz}.bval
dwi_bvec=${dwi_nii%%.nii.gz}.bvec

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_FA.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p dwi/${FULLID_folder}/reconstruction

#Diffusion tensor estimation
dwi2tensor dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz \
           dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_tensor.nii.gz \
           -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz \
           -fslgrad \
           ${dwi_bvec} \
           ${dwi_bval} &&\

#Generate maps of tensor-derived parameters
tensor2metric dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_tensor.nii.gz \
              -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz \
              -adc dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_MD.nii.gz \
              -fa dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_FA.nii.gz \
              -ad dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_AD.nii.gz \
              -rd dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_RD.nii.gz \
              -vector dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_V1.nii.gz &&\

printf "\n#### Done! ####\n"