#!/bin/bash

#SBATCH --job-name=DWIpreproc         #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2       	  #max CPU cores per process
#SBATCH --time=00:30:00             #time limit (HH:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  		DWI preprocessing
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 04 05 2023
#status: done

#Review History
#Reviewed by Ismail Koubiyr (25 04 2023)

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform preprocessing  of the diffusion images.
#
# - Prerequisites: 
# - Input: Bids-style input directory, pipeline folder and the subject (+session) ID & preprocessed anat data
# - Output: Preprocessed and reconstructed diffusion images
#----------------------------------------------------------------------

#Input variables
INPUT_DIR=$(realpath $1)
FULLID_file=$2
FULLID_folder=$3

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p dwi/${FULLID_folder}/preprocessing

#dMRI noise level estimation and denoising using Marchenko-Pastur PCA
dwidenoise ${INPUT_DIR}/${FULLID_FOLDER}/dwi/${FULLID_file}_dwi.nii.gz \
           dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz &&\

#Remove Gibbs Ringing Artifacts
mrdegibbs dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz \
          dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz &&\

PE=$(cat ${INPUT_DIR}/${FULLID_FOLDER}/dwi/${FULLID_file}_dwi.json | grep "PhaseEncodingDirection" | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')
RT=$(cat ${INPUT_DIR}/${FULLID_FOLDER}/dwi/${FULLID_file}_dwi.json | grep "TotalReadoutTime" | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')

#Perform diffusion image pre-processing using FSL’s eddy tool; including inhomogeneity distortion correction using FSL’s topup tool
eddy_correct dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
             dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_eddycor_dwi.nii.gz \
             0 &&\

#Extract b0 volumes
dwiextract dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_eddycor_dwi.nii.gz \
           dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_b0s.nii.gz \
           -bzero \
           -fslgrad \
           ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bvec \
           ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bval &&\

#Mean b0
fslmaths dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_b0s.nii.gz \
         -Tmean dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0.nii.gz

#Use the FSL Brain Extraction Tool (bet) to generate a brain mask
bet dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0.nii.gz \
    dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0_brain.nii.gz \
    -m -f 0.2 &&\

#Perform DWI bias field correction using the N4 algorithm as provided in ANTs
dwibiascorrect ants \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_eddycor_dwi.nii.gz \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_eddycor_biascor_dwi.nii.gz \
               -fslgrad \
               ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bvec \
               ${INPUT_DIR}/dwi/${FULLID_FOLDER}/${FULLID_file}_dwi.bval \
               -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwi_meanb0_brain_mask.nii.gz &&\

#Create symbolic link with easier-to-find filename
ln -s ${FULLID_file}_denoised_unringed_eddycor_biascor_dwi.nii.gz \
      dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz

printf "\n#### Done! ####\n"


