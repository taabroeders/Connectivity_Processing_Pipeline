#!/bin/bash

#SBATCH --job-name=ICA-AROMA          #a convenient name for your job
#SBATCH --mem=1G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	   #max CPU cores per process
#SBATCH --time=2:00:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                            ICA-AROMA
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 03 04 2023
#status: Done

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It performs functional preprocessing using ICA-AROMA.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Neck-clipped and skull-stripped T1-scan, resting-state functional MRI,
#          pipeline-folder, number of dummy scans to remove and subject (+session) ID
# - Output: Preprocessed functional MRI scans, excluding temporal filtering.
#----------------------------------------------------------------------

#Input variables
anatomical=$1
FILEDIR=$2/files
FULLID=$3

#Check if script has already been completed
[ -d func/${FULLID}/ICA_AROMA ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID} | sed 's|/|: |')####\n\n"

#for each functional scan-session
echo "Running ICA-AROMA..." &&\

#perform ICA-AROMA
source activate ${FILEDIR}/preproc_env &&\
python ${FILEDIR}/ICA-AROMA/ICA_AROMA.py \
       -feat ${PWD}/func/${FULLID}/fmri.feat \
       -out ${PWD}/func/${FULLID}/ICA_AROMA/ &&\
conda deactivate &&\

printf "\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Pruim RHR, Mennes M, van Rooij D, Llera A, Buitelaar JK, Beckmann CF.
# ICA-AROMA: A robust ICA-based strategy for removing motion artifacts from fMRI data.
# Neuroimage. 2015 May 15;112:267-277. doi: 10.1016/j.neuroimage.2015.02.064.