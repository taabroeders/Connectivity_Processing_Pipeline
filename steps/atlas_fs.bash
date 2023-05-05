#!/bin/bash

#SBATCH --job-name=Atlas2FS             #a convenient name for your job
#SBATCH --mem=1G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:05:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                BRAINNETOME CORTICAL ATLAS TO FREESURFER
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
#   It will transform the Brainnetome Cortical Atlas freesurfer output to freesurfer space.
#
# - Prerequisites: Freesurfer tools enabled
# - Input: Script folder, freesurfer output folder, and the subject (+session) ID
# - Output: BNA in freesurfer-space
#----------------------------------------------------------------------

#Input variables
scriptfolder=$1
freesurfer_folder=$2
FULLID_folder=$3
FULLID_file=$4
SUBJECTS_DIR=freesurfer

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_rh.BN_Atlas.stats ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p anat/${FULLID_folder}/Atlas_to_FS &&\

#Map BNA to Freesurfer space
echo "Mapping BNA cortical parcellations to FS subject-space..." &&\

mris_ca_label -t ${scriptfolder}/files/BN_Atlas_210_LUT.txt \
              ${FULLID_file} lh ${freesurfer_folder}/surf/lh.sphere.reg \
              ${scriptfolder}/files/lh.BN_Atlas.gcs \
              anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_lh.BN_Atlas.annot &&\

mris_ca_label -t ${scriptfolder}/files/BN_Atlas_210_LUT.txt \
              ${FULLID_file} rh ${freesurfer_folder}/surf/rh.sphere.reg \
              ${scriptfolder}/files/rh.BN_Atlas.gcs \
              anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_rh.BN_Atlas.annot &&\

mris_anatomical_stats -mgz -cortex ${freesurfer_folder}/label/lh.cortex.label -f \
                      anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_lh.BN_Atlas.stats -b -a ${PWD}/anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_lh.BN_Atlas.annot -c \
                      ${scriptfolder}/files/BN_Atlas_210_LUT.txt ${FULLID_file} lh white &&\

mris_anatomical_stats -mgz -cortex ${freesurfer_folder}/label/rh.cortex.label -f \
                      anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_rh.BN_Atlas.stats -b -a ${PWD}/anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_rh.BN_Atlas.annot -c \
                      ${scriptfolder}/files/BN_Atlas_210_LUT.txt ${FULLID_file} rh white &&\

printf "\n#### Done! ####\n"