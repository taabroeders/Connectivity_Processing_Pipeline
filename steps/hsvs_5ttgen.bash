#!/bin/bash

#SBATCH --job-name=5TTgen             #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2      	      #max CPU cores per process
#SBATCH --time=0:30:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      HYBRID TISSUE SEGMENTATION
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 25 04 2023
#status: still being developed
#to-do: add comments for individual steps

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform tissue segmentation using FSL and Freesurfer tools.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Neck-clipped T1-scan, freesurfer output folder and the subject (+session) ID
# - Output: Cortical and subcortical GM/WM segmentations
#----------------------------------------------------------------------

#Input variables
anatomical=$1
FREESURFER_DIR=$2
FULLID_folder=$3
FULLID_file=$4
lesionmask=$5

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_cerebellum_anat.nii.gz ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p anat/${FULLID_folder}/hsvs_5tt &&\

#perform hybrid (FSL+freesurfer) tissue-type segmentation
echo "Performing 5TT segmentations..." &&\
5ttgen hsvs ${FREESURFER_DIR} anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_freesurfer.nii.gz \
       -white_stem -nocrop -nocleanup -scratch anat/${FULLID_folder}/hsvs_5tt/all_segmentations \
       -hippocampi first -thalami first &&\

#moving segmentations from freesurfer to native anatomical space
mri_vol2vol --mov anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_freesurfer.nii.gz \
            --targ ${anatomical} --regheader \
            --o anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat.nii.gz \
            --no-save-reg --nearest &&\

#setting pathological tissue to lesion mask if lesion mask provided
if [ ! -z ${lesionmask} ]; then
5ttedit -path ${lesionmask} \
        anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat.nii.gz \
        anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz
else
ln -s ${FULLID_file}_5tthsvs_anat.nii.gz \
      anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz
fi &&\

#move 5tt file in freesurfer-space to 5ttgen folder for overview
mv anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_freesurfer.nii.gz \
   anat/${FULLID_folder}/hsvs_5tt/all_segmentations/${FULLID_file}_5tthsvs_freesurfer.nii.gz &&\

#transform first segmentations to anat-space
mri_vol2vol --mov anat/${FULLID_folder}/hsvs_5tt/all_segmentations/first_all_none_firstseg.nii.gz \
            --targ ${anatomical} --regheader \
            --o anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_first_all_none_firstseg_anat.nii.gz \
            --no-save-reg --nearest &&\

#transform cerebellum segmentation to anat-space
mrconvert anat/${FULLID_folder}/hsvs_5tt/all_segmentations/FAST_1.mif \
          anat/${FULLID_folder}/hsvs_5tt/all_segmentations/FAST_1.nii.gz &&\

mri_vol2vol --mov anat/${FULLID_folder}/hsvs_5tt/all_segmentations/FAST_1.nii.gz \
            --targ ${anatomical} --regheader \
            --o anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_cerebellum_anat.nii.gz \
            --no-save-reg --nearest &&\

#zip the debug folder from 5ttgen, to save space
tar -czf anat/${FULLID_folder}/hsvs_5tt/all_segmentations.tar.gz \
    anat/${FULLID_folder}/hsvs_5tt/all_segmentations/ &&\

rm -r anat/${FULLID_folder}/hsvs_5tt/all_segmentations/ &&\

printf "\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Škoch, A., & Caspers, S. (2019). Hybrid Surface-Volume Segmentation for improved Anatomically-Constrained Tractography.
