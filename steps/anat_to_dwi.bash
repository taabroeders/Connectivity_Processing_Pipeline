#!/bin/bash

#SBATCH --job-name=anat_to_dwi           #a convenient name for your job
#SBATCH --mem=40G                     #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=6      	      #max CPU cores per process
#SBATCH --time=8:00:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  TISSUE SEGMENTATIONS TO DWI
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 04 05 2023
#status: still being developed
#to-do: ANTs registration?

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will transform the tissue segmentations from native anatomical to dwi space.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Freesurfer output folder and the subject (+session) ID
# - Output: Tissue segmentations and GM/WM interface in diffusion space
#----------------------------------------------------------------------

#Input variables
FULLID_file=$1
FULLID_folder=$2
FILEDIR=$3/files

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p dwi/${FULLID_folder}/anat2dwi/reg &&\
mkdir -p dwi/${FULLID_folder}/anat2dwi/hsvs_5tt &&\

#Transform 5TT files to DWI data
echo "Transforming segmentations to diffusion weighted data and creating the GM/WM interface..." &&\
          
#Rigid anat-to-dwi registration with ANTs
echo "  Registering anat to dwi space..." &&\
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$SLURM_CPUS_PER_TASK &&\
antsRegistrationSyN.sh -d 3 \
                       -f anat/${FULLID_folder}/${FULLID_file}_T1w_brain.nii.gz \
                       -m dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain.nii.gz \
                       -ta \
                       -o dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_ &&\

export PATH=$PATH:${FILEDIR} &&\

antsRegistration_affine_SyN.sh --moving-mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz \
                               --fixed-mask anat/${FULLID_folder}/${FULLID_file}_T1w_brain_mask.nii.gz \
                               --initial-transform dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_0GenericAffine.mat \
                               --skip-linear \
                               -o dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat.nii.gz \
                               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
					           anat/${FULLID_folder}/${FULLID_file}_T1w.nii.gz \
                               dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat_ &&\
#Apply to 5TT file
echo "  Bringing 5tt file in dwi space..." &&\
antsApplyTransforms -i anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz \
                    -r dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
                    -o dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz \
                    -t [dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_0GenericAffine.mat,1] \
                    -t dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat_1InverseWarp.nii.gz \
                    -d 3 -e 3 --verbose &&\

echo "  Creating GM/WM interface..." &&\
5tt2gmwmi dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz \
          dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz &&\

printf "\n#### Done! ####\n"