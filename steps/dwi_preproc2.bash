#!/bin/bash

#SBATCH --job-name=dwi_preproc2       #a convenient name for your job
#SBATCH --mem=3G                     #max memory per node
#SBATCH --partition=luna-short        #using luna short queue
#SBATCH --cpus-per-task=2       	  #max CPU cores per process
#SBATCH --time=01:00:00               #time limit (HH:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw                     #use anw-gpus
#SBATCH --gres=gpu:1g.10gb:1
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                  	  DWI preprocessing part 2
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: 

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
anatomical_brain=$(realpath $4)
FILEDIR=$5/files

dwi_nii=$(realpath ${INPUT_DIR}/dwi/${FULLID_file}*_dwi.nii.gz)
dwi_json=$(realpath ${dwi_nii%%.nii.gz}.json)
dwi_bval=$(realpath ${dwi_nii%%.nii.gz}.bval)
dwi_bvec=$(realpath ${dwi_nii%%.nii.gz}.bvec)

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#----------------------------------------------------------------------
#               Perform fieldmap-free distortion correction
#----------------------------------------------------------------------
if [ -f dwi/${FULLID_folder}/preprocessing/${FULLID_file}_acqparams.txt ];then

printf "Performing fieldmap-free distortion correction...\n"

fslroi dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/b0_all_topup.nii.gz \
       dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
       0 1 &&\

bet dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
    dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain.nii.gz \
    -m -f 0.4 &&\

eddy --imain=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
     --mask=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz \
     --acqp=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_acqparams.txt \
     --index=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_index.txt \
     --bvecs=${dwi_bvec} \
     --bvals=${dwi_bval} \
     --topup=dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/topup \
     --out=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi \
     --verbose || exit 1

else 

#----------------------------------------------------------------------
#                  Fieldmap-based distortion correction
#----------------------------------------------------------------------

printf "Performing fieldmaps-based distortion correction...\n"

dwifslpreproc dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
              dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi.nii.gz \
              -fslgrad \
              ${dwi_bvec} \
              ${dwi_bval} \
              -rpe_pair \
              -se_epi dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_pair.nii.gz \
              -align_seepi \
              -eddy_options " --slm=linear " \
              -pe_dir ${PE} \
              -readout_time ${RT} \
              -nocleanup \
              -scratch dwi/${FULLID_folder}/preprocessing/${FULLID_file}_dwifslpreproc &&\

fslroi dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi.nii.gz \
       dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
       0 1 &&\

bet dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_vol0.nii.gz \
    dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain.nii.gz \
    -m -f 0.4 || exit 1

fi

#----------------------------------------------------------------------
#                       Bias field correction
#----------------------------------------------------------------------

#Perform DWI bias field correction using the N4 algorithm as provided in ANTs
dwibiascorrect ants \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi.nii.gz \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_biascor_dwi.nii.gz \
               -fslgrad \
               ${dwi_bvec} \
               ${dwi_bval} \
               -mask dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_brain_mask.nii.gz &&\

#Create symbolic link with easier-to-find filename
ln -s ${FULLID_file}_eddy_unwarped_biascor_dwi.nii.gz \
      dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz &&\

printf "\n#### Done! ####\n"