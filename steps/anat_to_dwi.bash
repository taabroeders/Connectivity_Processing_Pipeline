#!/bin/bash

#SBATCH --job-name=anat2dwi           #a convenient name for your job
#SBATCH --mem=40G                     #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=8      	  #max CPU cores per process
#SBATCH --time=4:00:00                #time limit (H:MM:SS)
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

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p dwi/${FULLID_folder}/anat2dwi/reg &&\
mkdir -p dwi/${FULLID_folder}/anat2dwi/hsvs_5tt &&\

#Transform 5TT files to DWI data
echo "Transforming segmentations to diffusion weighted data and creating the GM/WM interface..." &&\
          
#Rigid anat-to-dwi registration with ANTs
echo "  Registering anat to dwi space..." &&\
fslroi anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz \
       dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_5tthsvs_anat_vol0.nii.gz \
       0 1 &&\

flirt -in dwi/${FULLID_folder}/preprocessing/b0_topup_brain.nii.gz \
      -ref dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_5tthsvs_anat_vol0.nii.gz \
      -interp nearestneighbour \
      -dof 6 \
      -omat dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_RigidTrans_dwi2anat.mat &&\

convert_xfm -omat dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_RigidTrans_anat2dwi.mat \
            -inverse dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_RigidTrans_dwi2anat.mat &&\

#Apply to 5TT file
echo "  Bringing 5tt file in dwi space..." &&\
flirt -ref dwi/${FULLID_folder}/preprocessing/b0_topup_brain.nii.gz \
      -in anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz \
      -out dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz \
      -applyxfm -init dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_RigidTrans_anat2dwi.mat &&\

echo "  Creating GM/WM interface..." &&\
5tt2gmwmi dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz \
          dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz &&\

printf "\n#### Done! ####\n"

#Code for ANTs registration

# antsRegistrationSyN.sh -d 3 \
#                        -f anat/${FULLID_folder}/${FULLID_file}_T1w_brain.nii.gz \
#                        -m dwi/${FULLID_folder}/preprocessing/b0_topup_brain.nii.gz \
#                        -ta \
#                        -o dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_ &&\

# ${FILEDIR}/antsRegistration_affine_SyN.sh --moving-mask dwi/${FULLID_folder}/preprocessing/b0_topup_brain_mask.nii.gz \
#                                           --fixed-mask anat/${FULLID_folder}/${FULLID_file}_T1w_brain_mask.nii.gz \
#                                           --initial-transform dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_0GenericAffine.mat \
#                                           --skip-linear \
#                                           -o dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat.nii.gz \
#                                           dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/b0_all_topup_vol0.nii.gz\
# 					              anat/${FULLID_folder}/${FULLID_file}_T1w_noneck.nii.gz \
#                                           dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat_ &&\

antsApplyTransforms -i anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz \
                    -r dwi/${FULLID_folder}/preprocessing/b0_topup_brain.nii.gz \
                    -o dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions_ANTS.nii.gz \
                    -t [dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_0GenericAffine.mat,1] \
                    -t dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat_1InverseWarp.nii.gz \
                    -d 3 -e 3 --verbose &&\