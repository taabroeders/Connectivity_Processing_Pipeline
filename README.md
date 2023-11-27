# Connectivity Processing pipeline

## How to use:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> [options/flags]`<br/>
For more elaborate examples, see below.
<br/>
### Required arguments:
  `-i [or --input] <input-folder>`<br/>
  `-o [or --output] <output-folder>`<br/>
  Note: the input-folder is subject/session-specific and the output-folder is not. The subject (+ session) subfolders will be automatically created in the output-folder.
### Optional arguments:
  `--remove_vols [or --remove-vols] <n>`<br/>
  remove first <n> volumes (func. preprocessing) default=0<br/>
  `--freesurfer <freesufer-folder>`<br/>
  use output folder of previous freesurfer run (anat. prepocessing)<br/>
  `--lesion-filled <lesion-filled T1>`<br/>
  use already lesion-filled t1 (anat. preprocessing) default=[nu lesion-filled]<br/>
  `--lesion-mask <lesion-mask>`<br/>
 use lesion mask (t1 space) for lesion filling (if no lesion-filled provided) and improved tractography default=[no lesions]<br/>
  `--func-sdc`<br/>
  perform fieldmap-less distortion correction on the functional data (experimental)
### Flags:
  `-a` perform anatomical preprocessing<br/>
  `-f` perform functional preprocessing<br/>
  `-d` perform diffusion preprocessing<br/>
  If no flags are provided, all steps will be performed.
<br/>
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
    fmap/[optional]
      sub-<subject#>[_ses-<session#>]_dir-*_epi.nii.gz
      sub-<subject#>[_ses-<session#>]_dir-*_epi.json
```
<br/>

## Before the first run
### Make sure the following variables are correctly set:
  - `export FSL_DIR=/path/to/fsl-x.x.x; export PATH=${FSL_DIR}/bin:${PATH}`
  - `export FREESURFER_HOME=/path/to/freesurferx.x.x; export PATH=${FREESURFER_HOME}/bin:${PATH}`
  - `export ANTSPATH=/path/to/ANTS/install/bin; export PATH=${ANTSPATH}:${PATH}`
  - `export MRTRIX_DIR=/path/to/MRtrix; export PATH=${MRTRIX_DIR}:${PATH}`

### Run the initialisation script
`bash init.bash`<br/>
This will download a few required files and set the appropriate conda environment.
 <br/>

## Example Usage:
### Full processing (basic usage):
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> [optional arguments]`<br/>
This will run the full processing pipeline, including anatomical, functional and difussion processing (if anat, func and dwi data are all available).<br/>
### Anatomical processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -a --freesurfer <freesurfer-folder> --lesion-mask <lesion-mask> --lesion-filled <lesion-filled T1>`<br/>
This will run only the anatomical part of the pipeline and shows all the associated optional arguments. This includes (1) skipping the freesurfer cortical reconstruction and using a previous freesurfer folder, (2) a lesion-mask will be used to create clean (i.e. normal-appearing) WM/CSF/GM segmentations and (3) lesion-filling will be skipped and a previously lesion-filled T1 will be used.<br/>
### Functional processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -f --remove_vols 2`<br/>
This will run only the functional part of the pipeline (only possible if the anatomical part has already been completed and the output is stored in the same output-folder). This example also shows all the associated optional argements of the funcitonal part, which includes (1) removing  a specified number of dummy scans and (2) performing fieldmap-less distortion correction (only do this if fieldmaps have not been acquired).<br/>
### Diffusion processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -d`<br/>
This will run only the diffusion part of the pipeline (also only possible if the anatomical part has already been completed and the output is stored in the same output-folder). No optional arguments are available for this part at this stage.

<br/>

## Contact
For questions please email [Tommy Broeders](mailto:t.broeders@amsterdamumc.nl).