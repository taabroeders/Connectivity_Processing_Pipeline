# Connectivity_Processing_pipeline

################################################################################
HOW TO USE:
bash Full_preProcessing.bash -i <input_folder> -o <output_folder> [options/flags]

Required arguments:
  -i [or --input] <input-folder>
  -o [or --output] <output-folder>
Optional arguments:
  --remove_vols [or --remove-vols] <n>               remove first <n> volumes (func. preprocessing) default=0
  --freesurfer <freesufer-folder>                    use output folder of previous freesurfer run (anat. prepocessing)
  --lesion-mask <lesion-mask>                        use lesion mask (t1 space) (diff. pipeline) default=[no lesions]
Flags:
  -a perform anatomical preprocessing
  -f perform functional preprocessing
  -d perform diffusion preprocessing
  If no flags are provided, all steps will be performed.

Important! A BIDS folder structure is required for the input-folder:

dataset_description.json
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

Make sure the following variables are correctly set:
  - export FSL_DIR=/path/to/fsl-x.x.x; export PATH=$FSL_DIR/bin:$PATH
  - export FREESURFER_HOME=/path/to/freesurferx.x.x; export PATH=$FREESURFER_HOME/bin:$PATH
  - export ANTSPATH=/path/to/ANTS/install/bin; export PATH=$ANTSPATH:$PATH
  - export MRTRIX_DIR=/path/to/MRtrix; export PATH=$MRTRIX_DIR:$PATH
  
Examples:
1. Anatomical processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -a --freesurfer <freesurfer-folder>
2. Functional processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -f --remove_vols 2
3. Diffusion processing:
    bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -d
################################################################################

