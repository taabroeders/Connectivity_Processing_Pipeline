#!/bin/bash

#SBATCH --job-name=DWIpreproc         #a convenient name for your job
#SBATCH --mem=30G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2       	  #max CPU cores per process
#SBATCH --time=07:00:00             #time limit (HH:MM:SS)
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
anatomical_brain=$(realpath $4)

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Check if script has already been completed
if [ -f dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p dwi/${FULLID_folder}/preprocessing

#----------------------------------------------------------------------
#                         dwidenoise and mrdegibbs
#----------------------------------------------------------------------

#dMRI noise level estimation and denoising using Marchenko-Pastur PCA
dwidenoise ${INPUT_DIR}/dwi/${FULLID_file}_dwi.nii.gz \
           dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz &&\

#Remove Gibbs Ringing Artifacts
mrdegibbs dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz \
          dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz &&\

#----------------------------------------------------------------------
#                         Synb0-DisCo
#----------------------------------------------------------------------

mkdir -p dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input &&\
mkdir -p dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output &&\

#Extract b0 volumes
fslroi dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
       dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/b0.nii.gz \
       0 1 &&\

#Use brain-extracted T1
cp ${anatomical_brain} dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/T1.nii.gz

#Determine Phase-Encoding Direction and Readout Time and create acquisition parameters file
PE=$(cat ${INPUT_DIR}/dwi/${FULLID_file}_dwi.json | grep "PhaseEncodingDirection" | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')
RT=$(cat ${INPUT_DIR}/dwi/${FULLID_file}_dwi.json | grep "TotalReadoutTime" | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')

if [ ${PE} == "i" ];then PE_FSL="1 0 0"
elif [ ${PE} == "-i" ];then PE_FSL="-1 0 0"
elif [ ${PE} == "j" ];then PE_FSL="0 1 0"
elif [ ${PE} == "-j" ];then PE_FSL="0 -1 0"
elif [ ${PE} == "k" ];then PE_FSL="0 0 1"
elif [ ${PE} == "-k" ];then PE_FSL="0 0 -1"
fi

echo ${PE_FSL} ${RT} >> dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt &&\
echo ${PE_FSL} 0.00 >> dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt &&\

#Run Synb0-DISCO for fieldmap-lesss distortion correction
singularity run -e -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO:/tmp \
            -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input:/INPUTS \
            -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output:/OUTPUTS \
            -B $FREESURFER_HOME/license.txt:/extra/freesurfer/license.txt \
             /scratch/anw/ikoubiyr/Softs/synb0-disco.sif \
             --stripped &&\ 
             ##^UPDATE THIS

NVOLS=$(fslval dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz dim4)
indx="";for ((i=1; i<=${NVOLS}; i+=1)); do indx="$indx 1";done;echo $indx > dwi/${FULLID_folder}/preprocessing/${FULLID_file}_index.txt

cp dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt \
   dwi/${FULLID_folder}/preprocessing/${FULLID_file}_acqparams.txt &&\

fslroi dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/b0_all_topup.nii.gz \
       dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/b0_all_topup_vol0.nii.gz \
       0 1 &&\

bet dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/b0_all_topup_vol0.nii.gz \
    dwi/${FULLID_folder}/preprocessing/b0_topup_brain.nii.gz \
    -m -f 0.4 &&\

#----------------------------------------------------------------------
#                         Eddy & bias field correction
#----------------------------------------------------------------------

eddy --imain=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
     --mask=dwi/${FULLID_folder}/preprocessing/b0_topup_brain_mask.nii.gz \
     --acqp=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_acqparams.txt \
     --index=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_index.txt \
     --bvecs=/${INPUT_DIR}/dwi/${FULLID_file}_dwi.bvec \
     --bvals=${INPUT_DIR}/dwi/${FULLID_file}_dwi.bval \
     --topup=dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output/topup \
     --out=dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi \
     --verbose &&\

#Perform DWI bias field correction using the N4 algorithm as provided in ANTs
dwibiascorrect ants \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_dwi.nii.gz \
               dwi/${FULLID_folder}/preprocessing/${FULLID_file}_eddy_unwarped_biascor_dwi.nii.gz \
               -fslgrad \
               ${INPUT_DIR}/dwi/${FULLID_file}_dwi.bvec \
               ${INPUT_DIR}/dwi/${FULLID_file}_dwi.bval \
               -mask dwi/${FULLID_folder}/preprocessing/b0_topup_brain_mask.nii.gz &&\

#Create symbolic link with easier-to-find filename
ln -s ${FULLID_file}_eddy_unwarped_biascor_dwi.nii.gz \
      dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz

printf "\n#### Done! ####\n"


