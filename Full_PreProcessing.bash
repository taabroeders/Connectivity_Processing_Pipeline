#!/bin/bash

#======================================================================
#               KNW-CONNECT Processing Pipeline
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: 

#Review History
#Reviewed by -

# Description:
# - This code will make it possible to perform anatomical, functional and 
#   diffusion preprocessing for functional and/or diffusion connectivity studies 
#
# - Prerequisites: A BIDS folder structure is required, the quality of the input data needs to be checked beforehand
# - Input: T1w, fMRI and/or dwi(+bval&bvec)
# - Output: Anatomical segmentations, fMRI timeseries and/or diffusion-based connectivity
#----------------------------------------------------------------------

print_usage() {
printf %"$(tput cols)"s |tr " " "#"
printf "\nHOW TO USE:\nbash Full_preProcessing.bash -i <input_folder> -o <output_folder> [options/flags]

Required arguments:
  -i [or --input] <input-folder>
  -o [or --output] <output-folder>
  Note: the input-folder is subject/session-specific and the output-folder is not. The subject (+session) subfolders will be automatically created in the output-folder.
Optional arguments:
  --remove_vols [or --remove-vols] <n>               remove first <n> volumes (func. preprocessing) default=0
  --freesurfer <freesufer-folder>                    use output folder of previous freesurfer run (anat. prepocessing)
  --lesion-filled <lesion-filled T1>                 use already lesion-filled t1 (anat. preprocessing) default=[nu lesion-filled]
  --lesion-mask <lesion-mask>                        use lesion mask (t1 space) for lesion filling (if no lesion-filled provided) and improved tractography default=[no lesions]
  --func-sdc                                         perform fieldmap-less distortion correction on the functional data (experimental)
Flags:
  -a perform anatomical preprocessing
  -f perform functional preprocessing
  -d perform diffusion preprocessing
  If no flags are provided, all steps will be performed.

Important! A BIDS folder structure is required for the input-folder:

sub-<subject#>/                                      <-- This is the <input-folder>
  ses-<session#>[optional]                           <-- If available, use this as the <input-folder>
    anat/
      sub-<subject#>[_ses-<session#>]_T1w.nii.gz
    func/[optional]
      sub-<subject#>[_ses-<session#>]_task-rest_bold.nii.gz
    dwi/[optional]
      sub-<subject#>[_ses-<session#>]_dwi.nii.gz
      sub-<subject#>[_ses-<session#>]_dwi.bval
      sub-<subject#>[_ses-<session#>]_dwi.bvec
    fmap/[optional]
      sub-<subject#>[_ses-<session#>]_dir-*_epi.nii.gz
      sub-<subject#>[_ses-<session#>]_dir-*_epi.json

Make sure the following variables are correctly set:
  - export FSL_DIR=/path/to/fsl-x.x.x; export PATH=\$FSL_DIR/bin:\$PATH
  - export FREESURFER_HOME=/path/to/freesurferx.x.x; export PATH=\$FREESURFER_HOME/bin:\$PATH
  - export ANTSPATH=/path/to/ANTS/install/bin; export PATH=\$ANTSPATH:\$PATH
  - export MRTRIX_DIR=/path/to/MRtrix; export PATH=\$MRTRIX_DIR:\$PATH
  
Examples:
1. Anatomical processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -a --freesurfer <freesurfer-folder>
2. Functional processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -f --remove_vols 2
3. Diffusion processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -d\n"
printf %"$(tput cols)"s |tr " " "#"
printf "\n\n"
exit
}

print_help() {
printf "Try: 'bash Full_preProcessing.bash --help' for more information.\n\n"
exit
}

sort_logs() {
output_fldr=$1
FULLID_fldr=$2

find ${output_fldr}/logs/ -type f -empty -delete
mkdir -p ${output_fldr}/logs/${FULLID_fldr}
for logs in ${output_fldr}/logs/*.out;do
  sublog=$(grep -l "####$(echo ${FULLID_fldr} | sed 's|/|: |')####" $(realpath ${logs}))
  [ -z ${sublog} ] || mv ${sublog} ${output_fldr}/logs/${FULLID_fldr}
done
[ $(ls -1 ${output_fldr}/dcgm-gpu-stats*.out 2>/dev/null | wc -l) -gt 0 ] && rm ${output_fldr}/dcgm-gpu-stats*.out
}

print_error() {
printf "An error occurred during processing, please check the log files.\n\n"
sort_logs $1 $2
exit
}

#----------------------------------------------------------------------
#               LOAD MODULES (remove this section on GitHub)
#----------------------------------------------------------------------
module load fsl/6.0.6.4
module load FreeSurfer/7.3.2-centos8_x86_64
module load ANTs/2.4.1
module load art/2.1
module load Anaconda3/2023.03
module load GCC/9.3.0
module load OpenMPI/4.0.3
module load MRtrix/3.0.3-Python-3.8.2

#----------------------------------------------------------------------
#                         Input variables
#----------------------------------------------------------------------

##initialize all variables
a_flag=0 #perform anatomical preprocessing
f_flag=0 #perform functional preprocessing
d_flag=0 #perform diffusion preprocessing
input_folder='' #input folder
output_folder='' #output folder
freesurfer_input='' #location of freesurfer input
lesionmask='' #location of lesion mask
lesionfilled='' #location of lesion-filled T1
remove_vols=0 #remove #n dummy volumes for functional preprocessing
func_sdc=0 #perform experimental fieldmap-less distortion correction on functional data
SUBID='' #subject identifier
SESID='' #session identifier

##check input arguments
[ $# -eq 0 ] && print_usage
while [ $# -gt 0 ] ; do
  case $1 in
    -a | --anat) a_flag=1 ;;
    -f | --func) f_flag=1 ;;
    -d | --dwi) d_flag=1 ;;
    -i | --input) input_folder=$(realpath "$2"); shift ;;
    -o | --output) output_folder=$(realpath "$2"); shift ;;
    --remove_vols | --remove-vols) remove_vols="$2"; shift ;;
    --freesurfer) freesurfer_input=$(realpath "$2"); shift ;;
    --lesion-mask | lesion_mask) lesionmask=$(realpath "$2"); shift ;;
    --lesion-filled | lesion_filled) lesionfilled=$(realpath "$2"); shift ;;
    --func-sdc | func_sdc) func_sdc=1 ;;
    -h|-\?|--help) print_usage ;;
    -?*) printf 'ERROR: Unknown option %s\n\n' "$1"; print_help ;;
    *) break ;;
  esac
  shift
done

##if no flags were used, set all to 1 (i.e. run all steps)
if [[ $a_flag -eq 0 && $f_flag -eq 0 && $d_flag -eq 0 ]];then
  a_flag=1
  f_flag=1
  d_flag=1
fi

##check if input and output folders were correctly set
for ii in "$input_folder" "$output_folder"; do if [ -z $ii ]; then
  printf "ERROR: Required arguments were not correctly set.\n\n"; print_help
fi;done;

##ensure compatibility with session subfolders
if [[ $(basename $input_folder) == sub-* ]];then
  SUBID=${input_folder##*sub-}
  FULLID_file=sub-${SUBID}
  FULLID_folder=sub-${SUBID}
elif [[ $(basename $input_folder) == ses-* ]] && [[ $(basename $(dirname $input_folder)) == sub-* ]];then
  SUBID=$(printf $input_folder | rev | cut -d/ -f2 | rev | sed 's/sub-//')
  SESID=$(printf $input_folder | rev | cut -d/ -f1 | rev | sed 's/ses-//')
  FULLID_file=sub-${SUBID}_ses-${SESID}
  FULLID_folder=sub-${SUBID}/ses-${SESID}
else
  printf "ERROR: Invalid structure of the input folder.\n\n"; print_help
fi

##set filenames in accordance with folder structure
anatomical_raw=${input_folder}/anat/${FULLID_file}*_T1w.nii.gz
anatomical_noneck=${output_folder}/anat/${FULLID_folder}/${FULLID_file}_T1w.nii.gz
anatomical_brain=${output_folder}/anat/${FULLID_folder}/${FULLID_file}_T1w_brain.nii.gz
fmri=${input_folder}/func/${FULLID_file}*_task-rest*_bold.nii.gz
dwi=${input_folder}/dwi/${FULLID_file}*_dwi.nii.gz
scriptfolder=$(dirname $(realpath $0))

# Check if all required files are available
if [[ ${a_flag} -eq 1 ]] && [ ! -f ${anatomical} ]; then
  printf "ERROR: Requested anatomical preprocessing, but no anatomical data found.\n\n"; print_help
fi
if [ ! -z ${freesurfer_input} ] && [ ! -f ${freesurfer_input}/stats/aseg.stats ]; then
  printf "ERROR: The supplied freesurfer folder is incorrect.\n\n"; print_help
fi
if [[ ${f_flag} -eq 1 ]] && [ ! -f ${fmri} ]; then
  printf "ERROR: Requested functional preprocessing, but no functional MRI data found.\n\n"; print_help
fi
if [[ ${d_flag} -eq 1 ]];then
if [ ! -f ${dwi} ] || [ ! -f ${dwi%%.nii.gz}.bval ] || [ ! -f ${dwi%%.nii.gz}.bvec ]  || [ ! -f ${dwi%%.nii.gz}.json ]; then
  printf "ERROR: Requested diffusion preprocessing, but not all diffusion data found.\n\n"; print_help
fi
fi

# Check modules
if [[ ${a_flag} -eq 1 ]]; then
bash ${scriptfolder}/steps/check_env.bash || print_help
fi

if [[ ${f_flag} -eq 1 ]]; then
bash ${scriptfolder}/steps/check_env.bash -func_proc || print_help
fi

if [[ ${d_flag} -eq 1 ]]; then
bash ${scriptfolder}/steps/check_env.bash -dti_proc || print_help
fi

# Create the output folder
mkdir -p ${output_folder} && cd $_

# Create the log folder
mkdir -p ${output_folder}/logs/

# Set default freesurfer output folder
freesurfer_folder=${output_folder}/freesurfer/${FULLID_file}

printf %"$(tput cols)"s |tr " " "#"; printf "\n"
echo "Processing $(echo ${FULLID_folder} | sed 's|/|: |')"
printf %"$(tput cols)"s |tr " " "#"; printf "\n"

#----------------------------------------------------------------------
#                Anatomical preprocessing
#----------------------------------------------------------------------
if [[ ${a_flag} -eq 1 ]];then

printf %"$(tput cols)"s |tr " " "-"; printf "\n"
printf 'Anatomical preprocessing\n'
printf %"$(tput cols)"s |tr " " "-"; printf "\n"

# lesion filling
if [ ! -z ${lesionmask} ] && [ -z ${lesionfilled} ]; then
  echo "Performing lesion-filling..."
  anatomical=${output_folder}/anat/${FULLID_folder}/lesion_filling/${FULLID_file}_lesionfilled_anat.nii.gz
  sbatch --wait ${scriptfolder}/steps/lesionfilling.bash ${anatomical_raw} ${lesionmask} ${scriptfolder} ${FULLID_folder} ${FULLID_file} || print_error ${output_folder} ${FULLID_folder}
  elif [ ! -z ${lesionfilled} ]; then
  echo "The provided lesion-filled T1 will be used for processing"
  anatomical=${lesionfilled}
  else
  anatomical=${anatomical_raw}
  echo "No lesion mask provided. Skipping lesion-filling..."
fi

# Surface-reconstruction
if [ -d ${freesurfer_folder} ]; then
  echo "Freesurfer output directory already exists. Skipping this step..."
elif [ -f ${freesurfer_input}/stats/aseg.stats ];then
  echo "Using previous Freesurfer run. Copying to output directory..."
  mkdir -p ${output_folder}/freesurfer/
  cp -r ${freesurfer_input} ${freesurfer_folder}
else
  echo "Starting freesurfer processing..."
  mkdir -p ${output_folder}/freesurfer
  sbatch --wait ${scriptfolder}/steps/freesurfer.bash ${anatomical} ${output_folder}/freesurfer ${FULLID_file} || print_error ${output_folder} ${FULLID_folder}
fi

# Volumetric segmentation and registration
if [ -f ${output_folder}/anat/${FULLID_folder}/atlas/${FULLID_file}_BNA2highres_FIRST.nii.gz ]; then
  echo "Anatomical output directory already exists. Skipping this step..."
else
  echo "Starting volumetric processing..."
  mkdir -p ${output_folder}/anat/${FULLID_folder} &&\
  echo "  Mapping BNA cortical parcellations to FS subject-space..." &&\
  sbatch --wait ${scriptfolder}/steps/atlas_fs.bash ${scriptfolder} ${freesurfer_folder} ${FULLID_folder} ${FULLID_file} &&\
  echo "  Mapping parcellations and segmentations to T1 space..." &&\
  sbatch --wait ${scriptfolder}/steps/fs_to_anat.bash ${anatomical} ${anatomical_noneck} ${anatomical_brain} ${freesurfer_folder} ${FULLID_folder} ${FULLID_file} &&\
  echo "  Performing hybrid 5TT segmentations..." &&\
  sbatch --wait ${scriptfolder}/steps/hsvs_5ttgen.bash ${anatomical_noneck} ${freesurfer_folder} ${FULLID_folder} ${FULLID_file} ${scriptfolder} ${lesionmask} &&\
  echo "  Mapping BNA to T1 space..." &&\
  sbatch --wait ${scriptfolder}/steps/atlas_anat.bash ${FULLID_folder} ${FULLID_file} || print_error ${output_folder} ${FULLID_folder}
fi

fi

#----------------------------------------------------------------------
#                     Functional Processing
#----------------------------------------------------------------------
if [[ ${f_flag} -eq 1 ]];then

printf %"$(tput cols)"s |tr " " "-"; printf "\n"
printf 'Functional preprocessing\n'
printf %"$(tput cols)"s |tr " " "-"; printf "\n"

if [ ! -f ${fmri} ]; then
  printf "ERROR: Requested functional preprocessing, but no functional MRI data found!\n\n"; print_help
elif [ ! -d ${output_folder}/anat/${FULLID_folder}/atlas ]; then
  printf "ERROR: Requested functional preprocessing, but anatomical preprocessing not completed!\n\n"; print_help
fi

if [ -f ${output_folder}/func/${FULLID_folder}/atlas/denoised_func_data_nonaggr_hptf_BNatlas_timeseries.txt ]; then
  echo "Functional MRI timeseries already exists. Remove the output folders if you would like to run functional preprocessing again, skipping for now..."
else
  echo "Starting processing of functional MRI data..."
  mkdir -p ${output_folder}/func/${FULLID_folder}
  if [ $func_sdc -eq 1 ]; then
  echo "  Performing fieldmap-less distortion correction..." &&\
  sbatch --wait ${scriptfolder}/steps/func_sdc.bash ${anatomical_brain} ${fmri} ${scriptfolder} ${FULLID_file} ${FULLID_folder} || print_error ${output_folder} ${FULLID_folder}
  fi
  echo "  Performing FEAT..." &&\
  sbatch --wait ${scriptfolder}/steps/feat.bash ${anatomical_noneck} ${anatomical_brain} ${fmri} ${scriptfolder} ${remove_vols} ${FULLID_folder} &&\
  echo "  Running ICA-AROMA..." &&\
  sbatch --wait ${scriptfolder}/steps/ica-aroma.bash ${anatomical_brain} ${scriptfolder} ${FULLID_folder} &&\
  echo "  Computing the nuisance timeseries for the WM and CSF signal..." &&\
  sbatch --wait ${scriptfolder}/steps/wmcsf.bash ${FULLID_folder} ${FULLID_file} &&\
  echo "  Applying temporal filtering and WM/CSF regression..." &&\
  sbatch --wait ${scriptfolder}/steps/tempfilt.bash ${FULLID_folder} ${FULLID_file} &&\
  echo "  Transforming functional data to standard-space..." &&\
  sbatch --wait ${scriptfolder}/steps/func_to_std.bash ${FULLID_folder} ${FULLID_file} &&\
  echo "  Computing functional timeseries using Brainnetome Atlas..." &&\
  sbatch --wait ${scriptfolder}/steps/atlas_func.bash ${FULLID_folder} ${FULLID_file} || print_error ${output_folder} ${FULLID_folder}
fi

fi

#----------------------------------------------------------------------
#                       Diffusion Processing
#----------------------------------------------------------------------
if [[ ${d_flag} -eq 1 ]];then

printf %"$(tput cols)"s |tr " " "-"; printf "\n"
printf 'Diffusion preprocessing\n'
printf %"$(tput cols)"s |tr " " "-"; printf "\n"

if [ ! -f ${dwi} ]; then
  printf "ERROR: Requested diffusion preprocessing, but no diffusion data found!\n\n"; print_help
elif [ ! -d ${output_folder}/anat/${FULLID_folder}/atlas ]; then
  printf "ERROR: Requested diffusion preprocessing, but anatomical preprocessing not completed!\n\n"; print_help
fi

if [ -f ${output_folder}/dwi/${FULLID_folder}/atlas/BNA_Atlas_FA.csv ]; then
  echo "Diffusion MRI connectivity matrix already exists. Remove the output folders if you would like to run diffusion preprocessing again, skipping for now..."
else
  echo "Starting processing of diffusion weighted data..."
  echo "  Starting diffusion preprocessing..." &&\
  sbatch --wait ${scriptfolder}/steps/dwi_preproc1.bash ${input_folder} ${FULLID_file} ${FULLID_folder} ${anatomical_brain} ${scriptfolder} &&\
  sbatch --wait ${scriptfolder}/steps/dwi_preproc2.bash ${input_folder} ${FULLID_file} ${FULLID_folder} ${anatomical_brain} ${scriptfolder} &&\
  echo "  Starting diffusion reconstruction..." &&\
  sbatch --wait ${scriptfolder}/steps/dwi_recon.bash ${input_folder} ${FULLID_file} ${FULLID_folder} &&\
  echo "  Transforming 5TT segmentations to dwi and create GM/WM interface..." &&\
  sbatch --wait ${scriptfolder}/steps/anat_to_dwi.bash ${FULLID_file} ${FULLID_folder} ${scriptfolder} &&\
  echo "  Performing tractography and SIFT filtering..." &&\
  sbatch --wait ${scriptfolder}/steps/tractography.bash ${input_folder} ${FULLID_file} ${FULLID_folder} ${scriptfolder} &&\
  echo "  Computing structural connectivity matrices..." &&\
  sbatch --wait ${scriptfolder}/steps/atlas_dti.bash ${anatomical_noneck} ${FULLID_file} ${FULLID_folder} || print_error ${output_folder} ${FULLID_folder}
fi

fi

#----------------------------------------------------------------------
#                       Move log files
#----------------------------------------------------------------------

sort_logs ${output_folder} ${FULLID_folder}

printf %"$(tput cols)"s |tr " " "#"; printf "\n"
printf 'Processing Completed!\n'
printf %"$(tput cols)"s |tr " " "#"; printf "\n"

#----------------------------------------------------------------------
#                       References, links, others, ...   
#----------------------------------------------------------------------

