# Connectivity Preprocessing Pipeline

## Contents
* [Overview](#overview)
* [How to use](#how-to-use)
* [Additional instructions](#additional-instructions)
* [Initialization](#initialization)
* [Example usage](#example-usage)

## Overview
This code will perform anatomical, functional and diffusion preprocessing to facilitate  resting-state functional connectivity and/or diffusion-based structural connectivity studies. Including:<br/>
#### Anatomical preprocessing
 - (Freesurfer needs to have been run independently beforehand)
 - Mapping Brainnetome Atlas' cortical parcellations to freesurfer-space
 - Mapping parcellations and segmentations from freesurfer to T1 space
 - Performing hybrid 5TT segmentations (including FIRST for deep grey matter)
 - Adding FIRST deep grey matter regions to cortical regions from Brainnetome atlas (hybrid FIRST-Brainnetome Atlas)
 - Mapping BNA to T1 space
 #### Functional preprocessing
 - Performing distortion correction (with or without fieldmaps)
 - Dummy-scan removal, slice-time correction, co-registration, registration to standard-space and gaussian smoothing in FEAT
 - Motion artefact removal using ICA-AROMA
 - Removing mean white-matter and CSF signal
 - High-pass temporal filtering
 - Computing functional timeseries using hybrid FIRST-Brainnetome Atlas
 - Create functional connectivity matrix
 #### Diffusion preprocessing
 - Denoising
 - Gibbs ringing artefact removal
 - B1 field inhomogeneity, eddy current and bias field correction
 - Registration to standard-space using ANTs
 - Producing multi-tissue fiber response functions (dhollander)
 - Creating fiber orientation distributions (FODs) using constrained spherical deconvolution
 - Probabilistic tractography (iFOD2)
 - Streamline regularization (SIFT/SIFT2)
 - Create structural connectivity matrix

### Please use the following citation to refer to this work:
Broeders T.A.A., Koubiyr I., Schoonheim M.M. (2024). Connectivity Preprocessing Pipeline. GitHub. https://github.com/taabroeders/Connectivity_Processing_Pipeline<br/>

## How to use
`bash Full_PreProcessing.bash -i <input_folder> -o <output_folder> [options/flags]`<br/>
For more elaborate examples, see below.<br/>

### Slurm usage
To submit scripts of the individual steps to the slurm workload manager (sbatch), use `bash full_PreProcessing_slurm.bash`

### Required arguments:
  `-i [or --input] <input-folder>`<br/>
  `-o [or --output] <output-folder>`<br/>

### Optional arguments:
  `--freesurfer <freesufer-folder>`<br/>
  Path to the output folder of prior freesurfer run. This argument is required unless the folder is already copied to the output folder.<br/>
  `--lesion-filled <lesion-filled T1>`<br/>
  Use lesion-filled T1 (anat. preprocessing). If provided, lesion-mask is also required. default=[no lesion-filled]<br/>
  `--lesion-mask <lesion-mask>`<br/>
  Use lesion mask (in T1 space) default=[no lesions]<br/>
  <strong>Functional preprocessing</strong><br/>
  `--remove_vols <n>`<br/>
  Remove first <n> volumes (func. preprocessing) default=0<br/>
  `--skip_slice_time`<br/>
  Perform slice_time correction; default=[no slice-timing correction]<br/>
  `--func-sdc_fmap`<br/>
  Perform fieldmap-based distortion correction on the functional data (in development)<br/>
  `--func-sdc`<br/>
  Perform fieldmap-less distortion correction on the functional data (experimental)<br/>
  <strong>Diffusion preprocessing</strong><br/>
  `--dwi-sdc_fmap`<br/>
  Perform fieldmap-based distortion correction on the diffusion data<br/>
  `--dwi-sdc`<br/>
  Perform fieldmap-less distortion correction on the diffusion data (experimental)<br/>

### Flags:
  `-a` perform anatomical preprocessing<br/>
  `-f` perform functional preprocessing<br/>
  `-d` perform diffusion preprocessing<br/>
  If no flags are provided, all steps will be performed.<br/>

## Additional instructions
1. The `input folder` is subject/session-specific and the `output folder` is not. The subject (+session) subfolders will be automatically created in the output-folder (see example folder structure below for explanation).
2. If no flags are provided, all steps will be performed. Anatomical preprocessing needs to be completed before funcitonal or diffusion preprocessing can be performed.
3. The `--freesurfer argument` is required unless the folder is copied to output folder in the correct format:<br/>
&nbsp;&nbsp;`../output-folder/freesurfer/sub-<subject#>/`<br/>
&nbsp;&nbsp;`../output-folder/freesurfer/sub-<subject#>_ses-<session#>/`<br/>
4. If a `--lesion-filled` T1 is provided, a `--lesion-mask` is also required.
5. A BIDS folder structure is required for the input-folder.

### Example of a BIDS-compatible input folder
```
sub-<subject#>/                    <-- This is the <input-folder>
  ses-<session#>[optional]         <-- If available, this is the <input-folder>
    anat/
      sub-<subject#>[_ses-<session#>]_T1w.nii.gz
      sub-<subject#>[_ses-<session#>]_T1w.json
    func/[optional]
      sub-<subject#>[_ses-<session#>]_task-rest_bold.nii.gz
      sub-<subject#>[_ses-<session#>]_task-rest_bold.json
    dwi/[optional]
      sub-<subject#>[_ses-<session#>]_dwi.nii.gz
      sub-<subject#>[_ses-<session#>]_dwi.json
      sub-<subject#>[_ses-<session#>]_dwi.bval
      sub-<subject#>[_ses-<session#>]_dwi.bvec
    fmap/[optional]
      sub-<subject#>[_ses-<session#>]_*acq-bold_task-rest*_epi.nii.gz
      sub-<subject#>[_ses-<session#>]_*acq-bold_task-rest*_epi.json
      sub-<subject#>[_ses-<session#>]_*acq-dwi*_epi.nii.gz
      sub-<subject#>[_ses-<session#>]_*acq-dwi*_epi.json
```

## Initialization
### 1. Load all required modules
#### Option a: Using the <a href="https://modules.readthedocs.io/en/latest/" target="_blank">Environment Modules</a> package
Open the load_modules.bash script in any text-editor and replace the module names with the ones applicable to your system. Use `module spider` to search for modules, or contact your system administrator.
 
#### Option b: Setting the environmental variables manually
 - <a href="https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/Linux" target="_blank">FSL</a> <br/>
`export FSL_DIR=/path/to/fsl-x.x.x` <br/>
`export PATH=${FSL_DIR}/bin:${PATH}` <br/>
 - <a href="https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall" target="_blank">Freesurfer</a> <br/>
`export FREESURFER_HOME=/path/to/freesurferx.x.x` <br/>
`export PATH=${FREESURFER_HOME}/bin:${PATH}` <br/>
 - <a href="https://github.com/ANTsX/ANTs/wiki/Compiling-ANTs-on-Linux-and-Mac-OS" target="_blank">ANTS</a> <br/>
`export ANTSPATH=/path/to/ANTS/install/bin` <br/>
`export PATH=${ANTSPATH}:${PATH}` <br/>
 - <a href="https://www.mrtrix.org/download/linux-anaconda/" target="_blank">MRTRIX</a> <br/>
`export MRTRIX_DIR=/path/to/MRtrix` <br/>
`export PATH=${MRTRIX_DIR}:${PATH}` <br/>

### 2. Run the initialisation script
`bash init.bash`<br/>
This will download a few required files and set the appropriate conda environment.
 <br/>

## Example Usage
### Full processing (basic usage):
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> --freesurfer <freesurfer-folder> [optional arguments]`<br/>
This will run the full processing pipeline, including anatomical, functional and difussion processing (if anat, func and dwi data are all available).<br/>
### Anatomical processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> --freesurfer <freesurfer-folder> -a --lesion-mask <lesion-mask> --lesion-filled <lesion-filled T1>`<br/>
This will run only the anatomical part of the pipeline and shows all the associated optional arguments.
### Functional processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -f --remove_vols 2 --skip_slice_time --func_sdc`<br/>
This will run only the functional part of the pipeline (only possible if the anatomical part has already been completed). This example also shows some associated optional arguments of the functional part.<br/>
### Diffusion processing:
`bash Full_preProcessing.bash -i <input_folder> -o <output_folder> -d --dwi_sdc`<br/>
This will run only the diffusion part of the pipeline (also only possible if the anatomical part has already been completed). This example also shows an associated optional argument.<br/>

## Contact
For questions please email [Tommy Broeders](mailto:t.broeders@amsterdamumc.nl).