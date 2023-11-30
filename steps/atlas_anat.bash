#!/bin/bash

#SBATCH --job-name=atlas_anat         #a convenient name for your job
#SBATCH --mem=8G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:30:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      BNA IN NATIVE T1-SPACE
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: [optional] fancier overlap fix for DGM regions (see fs_to_anat.bash)
#       [optional] add compatibility with other atlasses

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will move the brainnetome atlas in native T1-space, including first segmentations for deep grey matter regions.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: The subject (+session) ID
# - Output: Cortical and subcortical regional segmentations in native T1-space
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2

#Check if script has already been completed
[ -f anat/${FULLID_folder}/atlas/BNA2highres_FIRST.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p anat/${FULLID_folder}/atlas &&\

#BNA to T1 space
echo "Mapping BNA to T1 space..." &&\
echo "  Adding cerebellum and subcortical segmentations..." &&\

#dilate atlas and cut with gm segmentation
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.cortex_t1.nii.gz -bin \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.cortex_t1_bin.nii.gz &&\

fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_t1.nii.gz -dilD \
         -mul anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.cortex_t1_bin.nii.gz \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_t1_dil_GMmasked.nii.gz &&\

##add cerebellum and subcortical segmentations to transformed atlas
#create cerebellum mask
fslmaths anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_cerebellum_anat.nii.gz -bin \
         -mul 225 anat/${FULLID_folder}/atlas/${FULLID_file}_225_cerebellum_LR.nii.gz &&\

#for readability
subcortseg=anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_first_all_none_firstseg_anat.nii.gz &&\

##create masks for subcortical segmentations and combine them
#create individual masks
fslmaths ${subcortseg} -thr 10 -uthr 10 -bin -mul 211 anat/${FULLID_folder}/atlas/${FULLID_file}_211_thalamus_L.nii.gz && \
fslmaths ${subcortseg} -thr 11 -uthr 11 -bin -mul 212 anat/${FULLID_folder}/atlas/${FULLID_file}_212_caudate_L.nii.gz && \
fslmaths ${subcortseg} -thr 12 -uthr 12 -bin -mul 213 anat/${FULLID_folder}/atlas/${FULLID_file}_213_putamen_L.nii.gz && \
fslmaths ${subcortseg} -thr 13 -uthr 13 -bin -mul 214 anat/${FULLID_folder}/atlas/${FULLID_file}_214_pallidum_L.nii.gz && \
fslmaths ${subcortseg} -thr 17 -uthr 17 -bin -mul 215 anat/${FULLID_folder}/atlas/${FULLID_file}_215_hippocampus_L.nii.gz && \
fslmaths ${subcortseg} -thr 18 -uthr 18 -bin -mul 216 anat/${FULLID_folder}/atlas/${FULLID_file}_216_amygdala_L.nii.gz && \
fslmaths ${subcortseg} -thr 26 -uthr 26 -bin -mul 217 anat/${FULLID_folder}/atlas/${FULLID_file}_217_accumbens_L.nii.gz && \
fslmaths ${subcortseg} -thr 49 -uthr 49 -bin -mul 218 anat/${FULLID_folder}/atlas/${FULLID_file}_218_thalamus_R.nii.gz && \
fslmaths ${subcortseg} -thr 50 -uthr 50 -bin -mul 219 anat/${FULLID_folder}/atlas/${FULLID_file}_219_caudate_R.nii.gz && \
fslmaths ${subcortseg} -thr 51 -uthr 51 -bin -mul 220 anat/${FULLID_folder}/atlas/${FULLID_file}_220_putamen_R.nii.gz && \
fslmaths ${subcortseg} -thr 52 -uthr 52 -bin -mul 221 anat/${FULLID_folder}/atlas/${FULLID_file}_221_pallidum_R.nii.gz && \
fslmaths ${subcortseg} -thr 53 -uthr 53 -bin -mul 222 anat/${FULLID_folder}/atlas/${FULLID_file}_222_hippocampus_R.nii.gz && \
fslmaths ${subcortseg} -thr 54 -uthr 54 -bin -mul 223 anat/${FULLID_folder}/atlas/${FULLID_file}_223_amygdala_R.nii.gz && \
fslmaths ${subcortseg} -thr 58 -uthr 58 -bin -mul 224 anat/${FULLID_folder}/atlas/${FULLID_file}_224_accumbens_R.nii.gz &&\

#combine masks
firstregs=$(ls anat/${FULLID_folder}/atlas/${FULLID_file}_2*.nii.gz) &&\
fslmerge -t anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_t1_dil_GMmasked.nii.gz \
         ${firstregs[@]} &&\

#remove possible overlap between regions
fslmaths anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz -Tmax \
         anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz &&\

printf "\n#### Done! ####\n"
