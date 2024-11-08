#!/bin/bash

#SBATCH --job-name=freesurfer         #a convenient name for your job
#SBATCH --mem=4G                      #max memory per node
#SBATCH --partition=luna-cpu-long     #using luna short queue
#SBATCH --cpus-per-task=4      	      #max CPU cores per process
#SBATCH --time=12:00:00               #time limit (H:MM:SS)
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                           FREESURFER
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed 
#to-do: [optional] incorporate longitudinal pipeline

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will run freesurfer recon-all.
#
# - Prerequisites: Freesurfer tools enabled
# - Input: T1-weighted MRI scan, output folder and the subject (+session) ID
# - Output: Freesurfer output
#----------------------------------------------------------------------

#Input variables
T1=$1
OUTPUTDIR=$2
FULLID=$3
SUBJECTS_DIR=${OUTPUTDIR}

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Run Freesurfer
echo "Starting freesurfer processing..." &&\
recon-all -subjid ${FULLID} -i ${T1} -all &&\

printf "\n\n$(date)\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# https://surfer.nmr.mgh.harvard.edu/
