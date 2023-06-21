#!/bin/bash

#SBATCH --job-name=TempFilterFunc     #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	  #max CPU cores per process
#SBATCH --time=0:15:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      TEMPORAL FILTERING
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 03 04 2023
#status: still being developed
#to-do: add comments for individual steps

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform temporal filtering and remove mean WM/CSF signal.
#
# - Prerequisites: FSL tools enabled
# - Input: Subject (+session) ID
# - Output: Denoised functional images
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f func/${FULLID_folder}/temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p func/${FULLID_folder}/temporal_filtering &&\

#Performing temporal filtering
echo "Applying temporal filtering and WM/CSF regression..."
echo "  Calculating temporal mean..."
fslmaths func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
         -Tmean func/${FULLID_folder}/temporal_filtering/${FULLID_file}_tempMean_func.nii.gz &&\

echo "  Performing temporal regression and demeaning..." &&\
fsl_glm -i func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
        -d func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries \
        --demean \
        --out_res=func/${FULLID_folder}/temporal_filtering/${FULLID_file}_residual.nii.gz &&\

# Determining TR
echo "  Setting the bptf value..." &&\
TR=$(fslval func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz pixdim4) &&\

# Calculating the highpass temporal filter cut-off
bptf=$(python -c "print(50/$TR)") &&\

echo "  Performing highpass filtering and adding temporal mean back again..." &&\
fslmaths func/${FULLID_folder}/temporal_filtering/${FULLID_file}_residual.nii.gz \
         -bptf $bptf \
         -1 \
         -add func/${FULLID_folder}/temporal_filtering/${FULLID_file}_tempMean_func.nii.gz \
         func/${FULLID_folder}/temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz &&\

#create symbolic link with easier-to-find filename
ln -s temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz \
      func/${FULLID_folder}/${FULLID_file}_preprocessed_func.nii.gz &&\

printf "\n#### Done! ####\n"