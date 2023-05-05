#!/bin/bash

#SBATCH --job-name=tractography       #a convenient name for your job
#SBATCH --mem=9G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=12            #max CPU cores per process
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

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_sift2weights.csv ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p dwi/${FULLID_folder}/tractography/tracts &&\

#Convert to .mif file (ss3t_csd_beta1 can't handle .nii.gz)
mrconvert  dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz \
           dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
           -fslgrad \
           ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bvec \
           ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bval &&\

#Estimate response function(s) for spherical deconvolution
dwi2response dhollander dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wm.txt \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gm.txt \
             dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csf.txt \
             -fslgrad \
             ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bvec \
             ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bval &&\

#Single-shell 3-tissue constrianed spherical deconvolution
source activate ${FILEDIR}/preproc_env &&\

export PATH=$PATH:${FILEDIR}/preproc_env/MRtrix3Tissue/bin &&\

ss3t_csd_beta1 dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wm.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gm.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_gmFOD.nii.gz \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csf.txt \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_csfFOD.nii.gz \
               -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0_brain_mask.nii.gz &&\

conda deactivate &&\

#Remove .mif file to save storage space
rm dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_preprocessed_dwi.mif &&\

# Perform tractograhy and tract filtering
printf "Performing tractography and SIFT2 filtering...\n\n" &&\
tckgen -act dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz  \
       -backtrack -select 10000000 \
       -seed_gmwmi dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_gmwmi_dwi.nii.gz \
       dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
       dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck &&\

# sift filtering
tcksift dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
        dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
        dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck &&\

# sift2 filtering
tcksift2 -act dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_5tthsvs_dwi_lesions.nii.gz  \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_response_wmFOD.nii.gz \
         dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_sift2weights.csv &&\

# generate tck file with less streamlines (for visualization purposes)
tckedit dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
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