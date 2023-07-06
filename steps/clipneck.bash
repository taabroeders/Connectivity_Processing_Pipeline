#!/bin/bash

#SBATCH --job-name=ClipNeck           #a convenient name for your job
#SBATCH --mem=1G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:30:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                           Clip the Neck
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 03 04 2023
#status: Done

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will remove the neck from the T1-weighed MRI scan.
#
# - Prerequisites: FSL tools enabled
# - Input: T1-weighted MRI scan, name of the outpu file and the subject (+session) ID
# - Output: Neck-clipped T1-scan
#----------------------------------------------------------------------

#Input variables
anatomical_raw=$1
anatomical_noneck=$2
FULLID=$3

#Check if script has already been completed
[ -f ${anatomical_noneck} ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID} | sed 's|/|: |')####\n\n"

#Clip the Neck from the T1-weighted image
printf "Clipping neck...\n" &&\
fslreorient2std ${anatomical_raw} ${anatomical_noneck} &&\
standard_space_roi ${anatomical_noneck} ${anatomical_noneck} -maskFOV -roiNONE &&\

printf "\n#### Done! ####\n"