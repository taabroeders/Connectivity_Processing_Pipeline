#!/bin/bash

#SBATCH --job-name=WMCSFmasks         #a convenient name for your job
#SBATCH --mem=3                       #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	  #max CPU cores per process
#SBATCH --time=0:05:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out


#======================================================================
#                      WM/CSF NUISANCE TIMESERIES
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
#   It will create white-matter and CSF nuisance timeseries.
#
# - Prerequisites: FSL tools enabled
# - Input: Subject (+session) ID
# - Output: WM/CSF nuisance timeseries
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2
fmrifeat=func/${FULLID_folder}/fmri.feat

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n\n" &&\

#Check if script has already been completed
if [ -f func/${FULLID_folder}/nuisance/nuisance_timeseries ];then
echo "WARNING: This step has already been completed. Skipping..."
exit 0
fi

#Create output folder
mkdir -p func/${FULLID_folder}/nuisance &&\

#create epi-distortion mask
echo "Creating the nuisance timeseries for the WM and CSF signal..." &&\
echo "  Creating an epi-distortion mask..." &&\

fslmaths func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
         -Tmin -thrP 25 -bin \
         func/${FULLID_folder}/nuisance/${FULLID_file}_minmask.nii.gz &&\

##Create the WM mask
echo "  Transforming WM mask to fMRI and extracting timeseries..." &&\

#Extract WM mask from 5tt file
fslroi anat/${FULLID_folder}/hsvs_5tt/${FULLID_file}_5tthsvs_anat_lesions.nii.gz \
       func/${FULLID_folder}/nuisance/${FULLID_file}_5tthsvs_WMmask_anat.nii.gz \
       2 1 &&\

#erode the WM-mask
fslmaths func/${FULLID_folder}/nuisance/${FULLID_file}_5tthsvs_WMmask_anat.nii.gz \
         -ero -bin \
         func/${FULLID_folder}/nuisance/${FULLID_file}_5tthsvs_WMmask_anat_eroded.nii.gz &&\

#linearly transform the WM_nofirst-mask to the functional data for all runs
flirt -in func/${FULLID_folder}/nuisance/${FULLID_file}_5tthsvs_WMmask_anat_eroded.nii.gz \
      -applyxfm \
      -init ${fmrifeat}/reg/highres2example_func.mat \
      -ref ${fmrifeat}/example_func.nii.gz \
      -out func/${FULLID_folder}/nuisance/${FULLID_file}_WMmask2func.nii.gz \
      -interp nearestneighbour &&\

#Multiple with the minmask
fslmaths func/${FULLID_folder}/nuisance/${FULLID_file}_WMmask2func.nii.gz \
         -mul func/${FULLID_folder}/nuisance/${FULLID_file}_minmask.nii.gz \
         func/${FULLID_folder}/nuisance/${FULLID_file}_WMmask2func_minmasked.nii.gz &&\

#print average timeseries over all voxels in WM_nofirst-mask for all runs
fslmeants -i func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
          -m func/${FULLID_folder}/nuisance/${FULLID_file}_WMmask2func_minmasked.nii.gz \
          -o func/${FULLID_folder}/nuisance/${FULLID_file}_wm_in_func_timeseries &&\

##create the CSF mask
echo "  Creating the CSF mask, registering it to fMRI, and extracting timeseries..." &&\

#erode the ventricle-mask created by freesurfer
mri_binarize --i anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_aparc.a2009s+aseg_anat.nii.gz \
             --o func/${FULLID_folder}/nuisance/${FULLID_file}_ventricles_anat.nii.gz --ventricles &&\

fslmaths func/${FULLID_folder}/nuisance/${FULLID_file}_ventricles_anat.nii.gz \
         -ero -bin func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst.nii.gz &&\

#linearly transform the ventricle-mask to the functional data for all runs
flirt -in func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst.nii.gz \
      -applyxfm \
      -init ${fmrifeat}/reg/highres2example_func.mat \
      -ref ${fmrifeat}/example_func.nii.gz \
      -out func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst2func.nii.gz \
      -interp nearestneighbour &&\

fslmaths func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst2func.nii.gz \
         -mul func/${FULLID_folder}/nuisance/${FULLID_file}_minmask.nii.gz \
         func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst2func_minmasked.nii.gz &&\

#print average timeseries over all voxels in CSF_nofirst_ventr-mask for all runs
fslmeants -i func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
          -m func/${FULLID_folder}/nuisance/${FULLID_file}_ventricle_mask-nofirst2func_minmasked.nii.gz \
          -o func/${FULLID_folder}/nuisance/${FULLID_file}_ventricles_in_func_timeseries &&\

##combine timeseries into single file
echo "  Combining WM and CSF timeseries for all runs..." &&\
paste func/${FULLID_folder}/nuisance/${FULLID_file}_wm_in_func_timeseries \
      func/${FULLID_folder}/nuisance/${FULLID_file}_ventricles_in_func_timeseries \
      > func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries &&\

printf "\n#### Done! ####\n"