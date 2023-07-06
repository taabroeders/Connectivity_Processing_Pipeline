#!/bin/bash

#SBATCH --job-name=FEAT               #a convenient name for your job
#SBATCH --mem=2G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	      #max CPU cores per process
#SBATCH --time=0:20:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                                 FEAT
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 03 04 2023
#status: Done

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It performs functional preprocessing using FEAT.
#
# - Prerequisites: FSL tools enabled
# - Input: Neck-clipped and skull-stripped T1-scan, resting-state functional MRI,
#          pipeline-folder, number of dummy scans to remove and subject (+session) ID
# - Output: Preprocessed functional MRI scans, excluding temporal filtering.
#----------------------------------------------------------------------

#Input variables
anatomical=$1
anatomical_brain=$2
restingstate=$3
subfolder=$4/files
delete_vols=$5
FULLID_folder=$6
outputdir=${PWD}/func/${FULLID_folder}
[ -f ${outputdir}/SynBOLD_DisCo/output/BOLD_u.nii.gz ] && restingstate=${outputdir}/SynBOLD_DisCo/output/BOLD_u.nii.gz

#Check if script has already been completed
[ -d ${outputdir}/fmri.feat ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n"

printf "Determining FEAT settings...\n" &&\

#load the TR
TR=$(fslval ${restingstate} pixdim4) &&\

#load the number of volumes
volnum=$(fslval ${restingstate} dim4) &&\

#load the number of voxels
numvoxels=$(fslhd ${restingstate} | grep ^dim[1/2/3/4] | awk '{print $2}' | paste -sd* - | bc) &&\

#copy the .fsf file describing the feat settings
cp ${subfolder}/feat_settings.fsf ${outputdir}/feat_settings.fsf &&\

#adjust the file to use subject specific paths
sed -i 's|ANATOMICAL_scan|'${anatomical_brain}'|g' ${outputdir}/feat_settings.fsf &&\
sed -i 's|FMRI_TR|'$(printf ${TR})'|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|N_VOL|'$(printf ${volnum})'|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|N_DELETE|'$(printf ${delete_vols})'|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|RESTINGSTATE|'${restingstate}'|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|NUMVOXELS|'${numvoxels}'|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|STANDARDBRAIN|"'${FSLDIR}'/data/standard/MNI152_T1_2mm_brain"|' ${outputdir}/feat_settings.fsf &&\
sed -i 's|OUTPUTDIR|"'${outputdir}'/fmri.feat"|' ${outputdir}/feat_settings.fsf &&\

#copy anatomical to same folder as anatomical (required for feat to work)
anatomical_feat_location=$(remove_ext ${anatomical_brain} | sed 's/_brain$//')".nii.gz" &&\
[ ${anatomical}==${anatomical_feat_location} ] || cp ${anatomical} ${anatomical_feat_location} &&\

##run FEAT
printf "Performing FEAT...\n" &&\
feat ${outputdir}/feat_settings.fsf &&\
rm ${outputdir}/feat_settings.fsf &&\

printf "\n#### Done! ####\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------
# Woolrich, M. W., Ripley, B. D., Brady, M., & Smith, S. M. (2001).
# Temporal Autocorrelation in Univariate Linear Modeling of FMRI Data.
# NeuroImage, 14(6), 13701386.
