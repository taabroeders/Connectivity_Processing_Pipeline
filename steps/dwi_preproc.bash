#!/bin/bash

#SBATCH --job-name=DWIpreproc         #a convenient name for your job
#SBATCH --mem=30G                     #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=2       	   #max CPU cores per process
#SBATCH --time=07:00:00               #time limit (HH:MM:SS)
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
FILEDIR=$5/files

dwi_nii=${INPUT_DIR}/dwi/${FULLID_file}*_dwi.nii.gz
dwi_json=${dwi_nii%%.nii.gz}.json
dwi_bval=${dwi_nii%%.nii.gz}.bval
dwi_bvec=${dwi_nii%%.nii.gz}.bvec

#Check if script has already been completed
[ -f dwi/${FULLID_folder}/preprocessing/${FULLID_file}_preprocessed_dwi.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

#Create output folder
mkdir -p dwi/${FULLID_folder}/preprocessing

#----------------------------------------------------------------------
#                         dwidenoise and mrdegibbs
#----------------------------------------------------------------------

#dMRI noise level estimation and denoising using Marchenko-Pastur PCA
dwidenoise ${dwi_nii} \
           dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz &&\

#Remove Gibbs Ringing Artifacts
mrdegibbs dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_dwi.nii.gz \
          dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz &&\

#Determine Phase-Encoding Direction and Readout Time and create acquisition parameters file
PE=$(cat ${dwi_json} | grep '"PhaseEncodingDirection"' | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')
RT=$(cat ${dwi_json} | grep '"TotalReadoutTime"' | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')

if [ ${PE} == "i" ];then PE_FSL="1 0 0"
elif [ ${PE} == "-i" ];then PE_FSL="-1 0 0"
elif [ ${PE} == "j" ];then PE_FSL="0 1 0"
elif [ ${PE} == "-j" ];then PE_FSL="0 -1 0"
elif [ ${PE} == "k" ];then PE_FSL="0 0 1"
elif [ ${PE} == "-k" ];then PE_FSL="0 0 -1"
fi

#----------------------------------------------------------------------
#                           Check for fieldmaps
#----------------------------------------------------------------------

b0pair_samePE=()
b0pair_otherPE=()
if [ -d ${INPUT_DIR}/fmap ];then
for b0pair_json in ${INPUT_DIR}/fmap/*.json; do
       if [ dwi == $(cat ${b0pair_json} | grep '"IntendedFor"' | cut -d'"' -f4 | cut -d/ -f 1) ]; then
              b0pair_nii=${b0pair_json%%.json}.nii.gz
              b0pair_PE=$(cat ${b0pair_json} | grep '"PhaseEncodingDirection"' | awk -F" " '{print $2}' | sed 's/"//g' | sed 's/,//g')
              if [ -f ${b0pair_nii} ];then
                     if [ "${b0pair_PE}" == "${PE}" ];then
                            b0pair_samePE+=("${b0pair_nii}")
                     else
                            b0pair_otherPE+=("${b0pair_nii}")
                     fi
              fi
       fi
done

fi

if [ -z ${b0pair_samePE} ] || [ -z ${b0pair_otherPE} ]; then
#----------------------------------------------------------------------
#                  Fieldmap-free distortion correction
#----------------------------------------------------------------------

printf "Performing fieldmap-free distortion correction...\n"

mkdir -p dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input &&\
mkdir -p dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output &&\

#Extract b0 volumes
fslroi dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz \
       dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/b0.nii.gz \
       0 1 &&\

#Use brain-extracted T1
cp ${anatomical_brain} dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/T1.nii.gz &&\

echo ${PE_FSL} ${RT} >> dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt &&\
echo ${PE_FSL} 0.00 >> dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt &&\

#Run Synb0-DISCO for fieldmap-free distortion correction
singularity run -e -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO:/tmp \
            -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input:/INPUTS \
            -B dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/output:/OUTPUTS \
            -B $FREESURFER_HOME/license.txt:/extra/freesurfer/license.txt \
             ${FILEDIR}/singularity/synb0-disco.sif \
             --stripped &&\

NVOLS=$(fslval dwi/${FULLID_folder}/preprocessing/${FULLID_file}_denoised_unringed_dwi.nii.gz dim4)
indx="";for ((i=1; i<=${NVOLS}; i+=1)); do indx="$indx 1";done;echo $indx > dwi/${FULLID_folder}/preprocessing/${FULLID_file}_index.txt

cp dwi/${FULLID_folder}/preprocessing/Synb0_DISCO/input/acqparams.txt \
   dwi/${FULLID_folder}/preprocessing/${FULLID_file}_acqparams.txt &&\

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
     --verbose || exit 0

else 

#----------------------------------------------------------------------
#                  Fieldmap-based distortion correction
#----------------------------------------------------------------------

printf "Using fieldmaps for distortion correction...\n"

#Create one b0pair file of b0s with opposite phase encoding directions
mrcat ${b0pair_samePE} ${b0pair_otherPE} dwi/${FULLID_folder}/preprocessing/${FULLID_file}_b0_pair.nii.gz -axis 3 &&\

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
    -m -f 0.4 || exit 0

fi

#----------------------------------------------------------------------
#                         Eddy & bias field correction
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


