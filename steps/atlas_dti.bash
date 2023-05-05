#!/bin/bash

#SBATCH --job-name=Atlas2DTI          #a convenient name for your job
#SBATCH --mem=300M                    #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2      	  #max CPU cores per process
#SBATCH --time=0:10:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      CREATE CONNECTIVITY MATRICES
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 04 05 2023
#status: still being developed
#to-do: Add compatibility with other atlasses

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will create connectivity matrices based on streamlines, FA & length.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Subject (+session) ID
# - Output: Cortical and subcortical GM/WM segmentations
#----------------------------------------------------------------------

#Input variables
anatomical=$1
FULLID_file=$2
FULLID_folder=$3

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_FA.csv ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p dwi/${FULLID_folder}/anat2dwi/atlas &&\
mkdir -p dwi/${FULLID_folder}/tractography/atlas &&\

#Transform atlas to dwi data and compute structural connectivity matrices
echo "Computing structural connectivity matrices..." &&\

#Apply anat-to-dwi transormation to atlas file
echo "  Bringing 5tt file in dwi space" &&\
# antsApplyTransforms -d 3 \
#                     -i anat/${FULLID_folder}/atlas/BNA2highres_FIRST.nii.gz \
#                     -r dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz \
#                     -o dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
#                     -n NearestNeighbor \
#                     -t dwi/${FULLID_folder}/anat2dwi/hsvs_5tt/${FULLID_file}_anat2dwi_0GenericAffine.mat &&\

flirt -ref dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0_brain.nii.gz \
      -in anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz \
      -out dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
      -applyxfm -init dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_RigidTrans_anat2dwi.mat \
      -interp nearestneighbour &&\

echo "  Computing connectivity matrices" &&\

# compute matrix (edges are sum of streamline weights)
#sift
tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_streamlines_sift.csv \
               -out_assignment dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_assignment_sift.csv &&\

#sift2
tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_streamlines_sift2.csv \
               -tck_weights_in dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_sift2weights.csv \
               -out_assignment dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_assignment_sift2.csv &&\

# compute matrix (edges are mean streamline length)
tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_length.csv \
               -scale_length -stat_edge mean &&\

# compute matrix (edges are mean FA)
tcksample dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
          dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_FA.nii.gz \
          dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_meanFAweights.csv \
          -stat_tck mean &&\

tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_FA.csv \
               -scale_file dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_meanFAweights.csv \
               -stat_edge mean &&\

printf "\n#### Done! ####\n"