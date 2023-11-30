#!/bin/bash

#SBATCH --job-name=lesionfilling      #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:30:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  		    Lesion Filling
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to do: [optional] add lesion segmentation?
#       [optional] other filling tool?

#Review History
#Reviewed by Ismail Koubiyr (25 04 2023)

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform preprocessing  of the diffusion images.
#
# - Prerequisites: 
# - Input: Bids-style input directory, pipeline folder and the subject (+session) ID & preprocessed anat data
# - Output: Preprocessed and reconstructed diffusion images
#----------------------------------------------------------------------

#Input variables
anatomical_raw=$1
lesion_mask=$2
FILEDIR=$3/files
FULLID_folder=$4
FULLID_file=$5

#Check if script has already been completed
[ -f anat/${FULLID_folder}/lesion_filling/${FULLID_file}_lesionfilled_anat.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p anat/${FULLID_folder}/lesion_filling &&\

#Perform lesion filling
echo "Performing lesion filling..."
${FILEDIR}/niftyseg/bin/seg_FillLesions \
    -i ${anatomical_raw} \
    -l ${lesion_mask} \
    -o anat/${FULLID_folder}/lesion_filling/${FULLID_file}_lesionfilled_anat.nii.gz &&\

printf "\n#### Done! ####\n"

