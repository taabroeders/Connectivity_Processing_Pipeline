# Connectivity Processing pipeline

## How to use:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> [options/flags]`
<br/><br/>
### Required arguments:
  `-i [or --input] <input-folder>`<br/>
  `-o [or --output] <output-folder>`
### Optional arguments:
  `--remove_vols [or --remove-vols] <n>`<br/>
  remove first <n> volumes (func. preprocessing) default=0<br/>
  `--freesurfer <freesufer-folder>`<br/>
  use output folder of previous freesurfer run (anat. prepocessing)<br/>
  `--lesion-mask <lesion-mask>`<br/>
  use lesion mask (t1 space) (diff. pipeline) default=[no lesions]<br/>
  `--func-sdc`<br/>
  perform fieldmap-less distortion correction on the functional data (experimental)
### Flags:
  `-a` perform anatomical preprocessing<br/>
  `-f` perform functional preprocessing<br/>
  `-d` perform diffusion preprocessing<br/>
  If no flags are provided, all steps will be performed.
<br/><br/>
## A BIDS folder structure is required for the input-folder:

```
sub-<subject#>                 <-- This is the <input-folder>
  ses-<session#>[optional]     <-- If available, use this as the <input-folder>
    anat/
      sub-<subject#>[_ses-<session#>]_T1w.nii.gz
    func/[optional]
      sub-<subject#>[_ses-<session#>]_task-rest_bold.nii.gz
    dwi/[optional]
      sub-<subject#>[_ses-<session#>]_dwi.nii.gz
      sub-<subject#>[_ses-<session#>]_dwi.bval
      sub-<subject#>[_ses-<session#>]_dwi.bvec
```
<br/><br/>

## Before the first run
### Make sure the following variables are correctly set:
  - `export FSL_DIR=/path/to/fsl-x.x.x; export PATH=${FSL_DIR}/bin:${PATH}`
  - `export FREESURFER_HOME=/path/to/freesurferx.x.x; export PATH=${FREESURFER_HOME}/bin:${PATH}`
  - `export ANTSPATH=/path/to/ANTS/install/bin; export PATH=${ANTSPATH}:${PATH}`
  - `export MRTRIX_DIR=/path/to/MRtrix; export PATH=${MRTRIX_DIR}:${PATH}`

### Run the initialisation script
`bash init.bash` 
 <br/><br/>

## Example Usage:
### Anatomical processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -a --freesurfer <freesurfer-folder> --lesion-mask <lesion-mask>`
### Functional processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -f --remove_vols 2`
### Diffusion processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -d`
<br/><br/>

## Contact
For questions please email [Tommy Broeders](mailto:t.broeders@amsterdamumc.nl).