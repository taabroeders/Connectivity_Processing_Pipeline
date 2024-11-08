#!/bin/bash

#SBATCH --job-name=ica-aroma          #a convenient name for your job
#SBATCH --mem=2G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	   #max CPU cores per process
#SBATCH --time=2:00:00                #time limit (H:MM:SS)
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                            ICA-AROMA
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to do: [optional] check how easy the conda environment implementation is

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It performs functional preprocessing using ICA-AROMA.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Neck-clipped and skull-stripped T1-scan, resting-state functional MRI,
#          pipeline-folder, number of dummy scans to remove and subject (+session) ID
# - Output: Preprocessed functional MRI scans, excluding temporal filtering.
#----------------------------------------------------------------------

#Input variables
anatomical=$1
FILEDIR=$2/files
FULLID=$3

#Check if script has already been completed
[ -d func/${FULLID}/ICA_AROMA ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID} | sed 's|/|: |')####\n$(date)\n\n"

#Select MC file
if [ -f ${PWD}/func/${FULLID}/SynBOLD_DisCo/output/rBOLD.par ];then
	nvol=$(fslval ${PWD}/func/${FULLID}/fmri.feat/filtered_func_data.nii.gz dim4)
	tail ${PWD}/func/${FULLID}/SynBOLD_DisCo/output/rBOLD.par -n ${nvol} > \
	${PWD}/func/${FULLID}/SynBOLD_DisCo/output/rBOLD_nodummy.par
	MCfile=${PWD}/func/${FULLID}/SynBOLD_DisCo/output/rBOLD_nodummy.par
else	
	MCfile=${PWD}/func/${FULLID}/fmri.feat/mc/prefiltered_func_data_mcf.par
fi

#for each functional scan-session
echo "Running ICA-AROMA..." &&\

#perform ICA-AROMA
eval "$(conda shell.bash hook)" &&\
conda activate ${FILEDIR}/preproc_env_ica &&\
${FILEDIR}/preproc_env_ica/bin/python ${FILEDIR}/ICA-AROMA/ICA_AROMA.py \
       -in ${PWD}/func/${FULLID}/fmri.feat/filtered_func_data.nii.gz \
       -a ${PWD}/func/${FULLID}/fmri.feat/reg/example_func2highres.mat \
       -w ${PWD}/func/${FULLID}/fmri.feat/reg/highres2standard_warp.nii.gz \
       -mc ${MCfile} \
       -out ${PWD}/func/${FULLID}/ICA_AROMA/ &&\
conda deactivate

[ ! -d ${PWD}/func/${FULLID}/ICA_AROMA/ ] && exit 1

printf "\n\n$(date)\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Pruim RHR, Mennes M, van Rooij D, Llera A, Buitelaar JK, Beckmann CF.
# ICA-AROMA: A robust ICA-based strategy for removing motion artifacts from fMRI data.
# Neuroimage. 2015 May 15;112:267-277. doi: 10.1016/j.neuroimage.2015.02.064.
