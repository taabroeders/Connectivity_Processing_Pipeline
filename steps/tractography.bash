#!/bin/bash

#SBATCH --job-name=tractography       #a convenient name for your job
#SBATCH --mem=9G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=16            #max CPU cores per process
#SBATCH --time=6:00:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                             TRACTOGRAPHY
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 04 05 2023
#status: still being developed
#to-do: -

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform tractography on the diffusion weighted data.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Subject (+session) ID
# - Output: Cortical and subcortical GM/WM segmentations
#----------------------------------------------------------------------

#Input variables
INPUT_DIR=$(realpath $1)
FULLID_file=$2
FULLID_folder=$3
FILEDIR=$4/files

dwi_nii=${INPUT_DIR}/dwi/${FULLID_file}*_dwi.nii.gz
dwi_bval=${dwi_nii%%.nii.gz}.bval
dwi_bvec=${dwi_nii%%.nii.gz}.bvec

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_sift2weights.csv ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Create output folder
mkdir -p dwi/${FULLID_folder}/tractography/tracts &&\

#Convert to .mif file (ss3t_csd_beta1 can't handle .nii.gz)
${FILEDIR}/singularity/MRtrix3.sif mrconvert  dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz \
           dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
           -fslgrad \
           ${dwi_bvec} \
           ${dwi_bval} &&\

#Estimate response function(s) for spherical deconvolution
${FILEDIR}/singularity/MRtrix3.sif dwi2response dhollander dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wm.txt \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gm.txt \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csf.txt \
             -fslgrad \
             ${dwi_bvec} \
             ${dwi_bval} &&\

#Single-shell 3-tissue constrianed spherical deconvolution
eval "$(conda shell.bash hook)" &&\
conda activate ${FILEDIR}/preproc_env &&\

export PATH=$PATH:${FILEDIR}/MRtrix3Tissue/bin &&\

ss3t_csd_beta1 dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wm.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gm.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gmFOD.nii.gz \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csf.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csfFOD.nii.gz \
               -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz &&\

conda deactivate &&\

#Remove .mif file to save storage space
rm dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif &&\

# Perform tractograhy and tract filtering
printf "Performing tractography and SIFT2 filtering...\n\n" &&\
${FILEDIR}/singularity/MRtrix3.sif tckgen -act dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz  \
       -backtrack -select 10000000 \
       -seed_gmwmi dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz \
       dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
       dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck &&\

# sift filtering
${FILEDIR}/singularity/MRtrix3.sif tcksift dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
        dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
        dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck &&\

# sift2 filtering
${FILEDIR}/singularity/MRtrix3.sif tcksift2 -act dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz  \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_sift2weights.csv &&\

# generate tck file with less streamlines (for visualization purposes)
${FILEDIR}/singularity/MRtrix3.sif tckedit dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
        -number 200k \
        dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_200k_ifod2.tck &&\

printf "\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Tournier, J.-D.; Calamante, F. & Connelly, A.
# Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions.
# Proceedings of the International Society for Magnetic Resonance in Medicine, 2010, 1670

# Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A.
# SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography.
# NeuroImage, 2015, 119, 338-351