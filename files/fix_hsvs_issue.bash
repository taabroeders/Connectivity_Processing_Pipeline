#!/bin/bash

SEGFOLDER=$(realpath $1)
FREESURFER_DIR=$(realpath $2)
output_file=$(realpath $3)
FILEDIR=$4
exclude=$5

echo " WARNING: HSVS issue detected. Applying in-house written fix by removing faulty vessel from freesurfer segmentation..."

#change working directory
cd $SEGFOLDER

#list which ventricle to include
include=$(ls *-vessel.mif | grep -v ${exclude})

#This is changed relative to original MRtrix  to exclude the faulty vessel
${FILEDIR}/singularity/MRtrix3.sif mrmath Left-Inf-Lat-Vent.mif 3rd-Ventricle.mif 4th-Ventricle.mif CSF.mif \
       ${include} \
       Right-Inf-Lat-Vent.mif 5th-Ventricle.mif Left_LatVent_ChorPlex.mif Right_LatVent_ChorPlex.mif \
       sum - | ${FILEDIR}/singularity/MRtrix3.sif mrcalc - 1.0 -min tissue3_init.mif -force

#Overwrite subsequent steps
${FILEDIR}/singularity/MRtrix3.sif mrmath Left-Lesion.mif Right-Lesion.mif sum - | ${FILEDIR}/singularity/MRtrix3.sif mrcalc - 1.0 -min tissue4.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue3_init.mif tissue3_init.mif tissue4.mif -add 1.0 -sub 0.0 -max -sub 0.0 -max tissue3.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrmath tissue3.mif tissue4.mif sum tissuesum_34.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue1_init.mif tissue1_init.mif tissuesum_34.mif -add 1.0 -sub 0.0 -max -sub 0.0 -max tissue1.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrmath tissue1.mif tissue3.mif tissue4.mif sum tissuesum_134.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue2_init.mif tissue2_init.mif tissuesum_134.mif -add 1.0 -sub 0.0 -max -sub 0.0 -max tissue2.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrmath tissue1.mif tissue2.mif tissue3.mif tissue4.mif sum tissuesum_1234.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue0_init.mif tissue0_init.mif tissuesum_1234.mif -add 1.0 -sub 0.0 -max -sub 0.0 -max tissue0.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrmath tissue0.mif tissue1.mif tissue2.mif tissue3.mif tissue4.mif sum tissuesum_01234.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc aparc.mif 6 -eq aparc.mif 7 -eq -add aparc.mif 8 -eq -add aparc.mif 45 -eq -add aparc.mif 46 -eq -add aparc.mif 47 -eq -add Cerebellum_volume.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc T1.nii Cerebellum_volume.mif -mult T1_cerebellum_precrop.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrgrid T1_cerebellum_precrop.mif crop -mask Cerebellum_volume.mif T1_cerebellum.nii -force

#This code is not affected by the exclusion of the vessel, so to save runtime this is excluded
#fast -N T1_cerebellum.nii
#${FILEDIR}/singularity/MRtrix3.sif mrtransform T1_cerebellum_pve_0.nii.gz -interp nearest -template aparc.mif FAST_0.mif -force
#${FILEDIR}/singularity/MRtrix3.sif mrtransform T1_cerebellum_pve_1.nii.gz -interp nearest -template aparc.mif FAST_1.mif -force

#Overwrite subsequents steps 
${FILEDIR}/singularity/MRtrix3.sif mrtransform T1_cerebellum_pve_2.nii.gz -interp nearest -template aparc.mif FAST_2.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc Cerebellum_volume.mif tissuesum_01234.mif -add 0.5 -gt 1.0 tissuesum_01234.mif -sub 0.0 -if Cerebellar_multiplier.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrconvert tissue0.mif tissue0_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue1.mif Cerebellar_multiplier.mif FAST_1.mif -mult -add tissue1_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue2.mif Cerebellar_multiplier.mif FAST_2.mif -mult -add tissue2_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue3.mif Cerebellar_multiplier.mif FAST_0.mif -mult -add tissue3_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrconvert tissue4.mif tissue4_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrmath tissue0_fast.mif tissue1_fast.mif tissue2_fast.mif tissue3_fast.mif tissue4_fast.mif sum tissuesum_01234_fast.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc 1.0 tissuesum_01234_fast.mif -sub tissuesum_01234_fast.mif 0.0 -gt ${FREESURFER_DIR}/mri/brainmask.mgz -add 1.0 -min -mult 0.0 -max csf_fill.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcalc tissue3_fast.mif csf_fill.mif -add tissue3_fast_filled.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrcat tissue0_fast.mif tissue1_fast.mif tissue2_fast.mif tissue3_fast_filled.mif tissue4_fast.mif - -axis 3 | \
${FILEDIR}/singularity/MRtrix3.sif 5ttedit - result.mif -none brain_stem_crop.mif -force
${FILEDIR}/singularity/MRtrix3.sif mrconvert result.mif ${output_file} -force
${FILEDIR}/singularity/MRtrix3.sif 5ttcheck result.mif
