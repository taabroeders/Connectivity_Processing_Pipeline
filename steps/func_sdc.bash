#!/bin/bash

#SBATCH --job-name=func_sdc           #a convenient name for your job
#SBATCH --mem=4G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2      	      #max CPU cores per process
#SBATCH --time=1:00:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                   Functional distortion correction
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to do:

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It performs functional preprocessing using FEAT.
#
# - Prerequisites: FSL tools enabled
# - Input: Neck-clipped and skull-stripped T1-scan, resting-state functional MRI,
#          pipeline-folder, number of dummy scans to remove and subject (+session) ID
# - Output: Preprocessed functional MRI scans, excluding temporal filtering.
#----------------------------------------------------------------------

#Input variables
anatomical_brain=$1
restingstate=$2
subfolder=$3/files
FULLID_file=$4
FULLID_folder=$5
outputdir=${PWD}/func/${FULLID_folder}

#Check if script has already been completed
[ -f ${outputdir}/SynBOLD_DisCo/output/BOLD_u.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#----------------------------------------------------------------------
#                         SynBOLD-DisCo
#----------------------------------------------------------------------

mkdir -p func/${FULLID_folder}/SynBOLD_DisCo/input &&\
mkdir -p func/${FULLID_folder}/SynBOLD_DisCo/output &&\

#Use raw BOLD
cp ${restingstate} func/${FULLID_folder}/SynBOLD_DisCo/input/BOLD_d.nii.gz

#Use brain-extracted T1
cp ${anatomical_brain} func/${FULLID_folder}/SynBOLD_DisCo/input/T1.nii.gz

#Run SynBOLD-DisCo for fieldmap-lesss distortion correction
singularity run -e -B func/${FULLID_folder}/SynBOLD_DisCo:/tmp \
            -B func/${FULLID_folder}/SynBOLD_DisCo/input:/INPUTS \
            -B func/${FULLID_folder}/SynBOLD_DisCo/output:/OUTPUTS \
            -B ${FREESURFER_HOME}/license.txt:/opt/freesurfer/license.txt \
             ${subfolder}/singularity/synbold-disco.sif \
             --skull_stripped


printf "\n\n$(date)\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Yu, T., Cai, L. Y., Morgan, V. L., Goodale, S. E., Englot, D. J., Chang, C. E., ...
# & Schilling, K. G. (2022). SynBOLD-DisCo: Synthetic BOLD images for distortion 
# correction of fMRI without additional calibration scans. bioRxiv, 2022-09.