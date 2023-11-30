#!/bin/bash

#SBATCH --job-name=atlas_dti          #a convenient name for your job
#SBATCH --mem=300M                    #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2      	      #max CPU cores per process
#SBATCH --time=0:10:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      CREATE CONNECTIVITY MATRICES
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: [optional] add compatibility with other atlasses

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

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_FA.csv ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p dwi/${FULLID_folder}/anat2dwi/atlas &&\
mkdir -p dwi/${FULLID_folder}/tractography/atlas &&\

#Transform atlas to dwi data and compute structural connectivity matrices
echo "Computing structural connectivity matrices..." &&\

#Apply anat-to-dwi transormation to atlas file
echo "  Bringing atlas file in dwi space" &&\
antsApplyTransforms -i anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz \
                    -r dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
                    -o dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
                    -t [dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_InitTrans_dwi2anat_0GenericAffine.mat,1] \
                    -t dwi/${FULLID_folder}/anat2dwi/reg/${FULLID_file}_FinalTrans_dwi2anat_1InverseWarp.nii.gz \
                    -n NearestNeighbor -d 3 -e 3 --verbose &&\
                    
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
#sift
tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_length_sift.csv \
               -scale_length -stat_edge mean &&\

#sift2
tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_length.csv \
               -scale_length -stat_edge mean &&\

# compute matrix (edges are mean FA)
#sift
tcksample dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
          dwi/${FULLID_folder}/reconstruction/${FULLID_file}_dwi_FA.nii.gz \
          dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_meanFAweights_sift.csv \
          -stat_tck mean &&\

tck2connectome -symmetric -zero_diagonal \
               dwi/${FULLID_folder}/tractography/tracts/${FULLID_file}_tracks_10M_ifod2_sift.tck \
               dwi/${FULLID_folder}/anat2dwi/atlas/${FULLID_file}_BNA_dwi.nii.gz \
               dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_BNA_Atlas_FA_sift.csv \
               -scale_file dwi/${FULLID_folder}/tractography/atlas/${FULLID_file}_meanFAweights_sift.csv \
               -stat_edge mean &&\

#sift2
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

printf "\n\n$(date)\n#### Done! ####\n"