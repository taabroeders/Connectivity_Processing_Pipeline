#!/bin/bash

#SBATCH --job-name=fs_to_anat         #a convenient name for your job
#SBATCH --mem=2500                    #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	  #max CPU cores per process
#SBATCH --time=0:30:00                #time limit (H:MM:SS)
#SBATCH --nice=2000                   #allow other priority jobs to go first
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                       FREESURFER TO NATIVE T1
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: remove gm/wm/csf segmentation step (will be done in other script: 5ttgen)

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will transform the freesurfer output to native T1 space.
#
# - Prerequisites: Freesurfer and FSL tools enabled
# - Input: Neck-clipped T1-scan, skull-stripped T1-scan, freesurfer output folder, and the subject (+session) ID
# - Output: freesurfer output and BNA in native T1-space
#----------------------------------------------------------------------

#Input variables
anatomical=$1
anatomical_noneck=$2
anatomical_brain=$3
freesurfer_folder=$4
FULLID_folder=$5
FULLID_file=$6
SUBJECTS_DIR=freesurfer

#Check if script has already been completed
[ -f anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_brain_anat.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p anat/${FULLID_folder}/FS_to_t1 &&\

# Map BNA to subjectslabel
printf "Mapping parcellations and segmentations to T1 space...\n" &&\

#transform atlas labels into volumetric atlas LH
mri_label2vol --annot anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_lh.BN_Atlas.annot \
              --temp ${freesurfer_folder}/mri/T1.mgz \
              --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01.mgz \
              --subject ${FULLID_file} --hemi lh --identity \
              --proj frac 0 1 0.01 &&\

#transform atlas labels into volumetric atlas RH
mri_label2vol --annot anat/${FULLID_folder}/Atlas_to_FS/${FULLID_file}_rh.BN_Atlas.annot \
              --temp ${freesurfer_folder}/mri/T1.mgz \
              --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01.mgz \
              --subject ${FULLID_file} --hemi rh --identity \
              --proj frac 0 1 0.01 &&\

#dilate the segmentations slightly LH
mri_convert anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01.mgz --dil-seg 1 \
            anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil.nii.gz &&\

#dilate the segmentations slightly RH
mri_convert anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01.mgz --dil-seg 1 \
            anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil.nii.gz &&\

#mask dilated atlas by the cortical GM ribbon LH
mris_calc -o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil_calc.nii.gz \
        anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil.nii.gz mul \
        ${freesurfer_folder}/mri/lh.ribbon.mgz &&\

#mask dilated atlas by the cortical GM ribbon LH
mris_calc -o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil_calc.nii.gz \
          anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil.nii.gz mul \
          ${freesurfer_folder}/mri/rh.ribbon.mgz &&\

#combine masked LH and RH atlasses
mri_concat --i anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil_calc.nii.gz \
           --i anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil_calc.nii.gz \
           --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas.nii.gz --sum &&\

##fix LR overlap
# binarize the LH atlas
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil_calc.nii.gz \
         -bin anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil_calc_bin.nii.gz &&\

# binarize the RH atlas
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil_calc.nii.gz \
         -bin anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil_calc_bin.nii.gz &&\

#sum the binarized LH and RH atlasses
mri_concat --i anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_lh_BN_Atlas_0-1_01_dil_calc_bin.nii.gz \
           --i anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_rh_BN_Atlas_0-1_01_dil_calc_bin.nii.gz \
           --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_comb.nii.gz --sum &&\

#identify voxels that are overlapping
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_comb.nii.gz -thr 2 \
         -bin anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_overlap

#identify voxels that ar non-overlapping
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_comb.nii.gz -thr 2 \
         -binv anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_no_overlap

#remove voxels from the comnbined masked LH and RH atlas that contain overlap
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas.nii.gz -mul \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_no_overlap \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_cut.nii.gz &&\

#use modular dilation to fill the voxels that initially contained overlap
fslmaths anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_cut.nii.gz -dilD -mul \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_LR_overlap.nii.gz \
         -add anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_cut.nii.gz \
         anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_cut_dil.nii.gz &&\

##Bring all atlases and segmentations to T1
#resample BNA to T1
mri_vol2vol --mov anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_cut_dil.nii.gz \
            --targ  ${anatomical} \
            --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_BN_Atlas_t1.nii.gz \
            --no-save-reg --nearest &&\

#create GM/WM/CSF segmentations
# mri_compute_volume_fractions --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac --regheader \
#                              ${FULLID_file} ${freesurfer_folder}/mri/norm.mgz &&\
# 
#Segmentations to T1
# B='cortex csf subcort_gm wm'
# for b in ${B}; do
# mri_convert anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.${b}.mgz \
#             anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.${b}.nii.gz &&\

# mri_vol2vol --mov anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.${b}.nii.gz \
#             --targ ${anatomical} \
#             --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_vol_frac.${b}_t1.nii.gz --no-save-reg || exit 1
# done

#destrieux atlas
mri_vol2vol --mov ${freesurfer_folder}/mri/aparc.a2009s+aseg.mgz \
            --targ ${anatomical} \
            --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_aparc.a2009s+aseg_anat.nii.gz --no-save-reg --nearest &&\

#DKT atlas
mri_vol2vol --mov ${freesurfer_folder}/mri/aparc.DKTatlas+aseg.mgz \
            --targ ${anatomical} \
            --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_aparc.DKTatlas+aseg_anat.nii.gz --no-save-reg --nearest &&\

#N3 corrected T1
mri_vol2vol --mov ${freesurfer_folder}/mri/nu.mgz \
            --targ ${anatomical} \
            --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_nu_anat.nii.gz --no-save-reg &&\

#brain-extracted T1
mri_vol2vol --mov ${freesurfer_folder}/mri/brain.mgz \
            --targ ${anatomical} \
            --regheader --o anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_brain_anat.nii.gz --no-save-reg &&\

#brain mask
fslmaths  anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_brain_anat.nii.gz \
          -bin anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_brainmask_anat.nii.gz &&\

#Remove neck
standard_space_roi anat/${FULLID_folder}/FS_to_t1/${FULLID_file}_nu_anat.nii.gz \
                   ${anatomical_noneck} -maskFOV -roiNONE

#Create symbolic link with easier-to-find filenames for brain extracted output
ln -s FS_to_t1/${FULLID_file}_brain_anat.nii.gz \
      ${anatomical_brain} &&\
ln -s FS_to_t1/${FULLID_file}_brainmask_anat.nii.gz \
      ${anatomical_brain%%.nii.gz}_mask.nii.gz &&\

printf "\n#### Done! ####\n"