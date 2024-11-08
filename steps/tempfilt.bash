#!/bin/bash

#SBATCH --job-name=TempFilterFunc     #a convenient name for your job
#SBATCH --mem=3G                      #max memory per node
#SBATCH --partition=luna-cpu-short    #using luna short queue
#SBATCH --cpus-per-task=1      	  #max CPU cores per process
#SBATCH --time=0:15:00                #time limit (H:MM:SS)
#SBATCH --qos=anw-cpu                 #use anw-cpu's
#SBATCH --output=logs/slurm-%x.%j.out

#======================================================================
#                      TEMPORAL FILTERING
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 30 11 2023
#status: still being developed
#to-do: check whether this is the right temporal filtering cut-off
#       [optional] add flexibility to filter motion parameters and perform scrubbing

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will perform temporal filtering and remove mean WM/CSF signal.
#
# - Prerequisites: FSL tools enabled
# - Input: Subject (+session) ID
# - Output: Denoised functional images
#----------------------------------------------------------------------

#Input variables
FULLID_folder=$1
FULLID_file=$2
advanced_tempfilt=$3

#Check if script has already been completed
[ -f func/${FULLID_folder}/temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz ] && exit 0

#Print the ID of the subject (& session if available)
printf "####$(echo ${FULLID_folder} | sed 's|/|: |')####\n$(date)\n\n"

#Create output folder
mkdir -p func/${FULLID_folder}/temporal_filtering &&\

if [ ${advanced_tempfilt} -eq 1 ];then
        #Select MC file
        if [ -f func/${FULLID_folder}/SynBOLD_DisCo/output/rBOLD.par ];then
                nvols=$(fslval func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz dim4)
                tail -n -${nvols} func/${FULLID_folder}/SynBOLD_DisCo/output/rBOLD.par \
                > func/${FULLID_folder}/SynBOLD_DisCo/output/rBOLD_nodummy.par
                MCfile=func/${FULLID_folder}/SynBOLD_DisCo/output/rBOLD_nodummy.par
        else
                MCfile=func/${FULLID_folder}/fmri.feat/mc/prefiltered_func_data_mcf.par
        fi

        nuisance_file=func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries_inclMP_derivatives

        ## Compute additional temporal filtering options
        echo "  Combining WM and CSF timeseries with motion parameters..." &&\
        paste func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries \
        ${MCfile} \
        > func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries_inclMP &&\

        echo "  Computing their derivatives..." &&\
        head -1 func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries_inclMP \
        | awk '{for(i=1;i<=NF;i++) {printf "0\t", $i-s[i]; s[i]=$i} print ""}' \
        > ${nuisance_file}

        awk 'NR==1{for(i=1;i<=NF;i++) s[i]=$i; next} {for(i=1;i<=NF;i++) {printf "%s\t", $i-s[i]; s[i]=$i} print ""}' \
        func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries_inclMP \
        >> ${nuisance_file}
else
        nuisance_file=func/${FULLID_folder}/nuisance/${FULLID_file}_nuisance_timeseries
fi

#Performing temporal filtering
echo "  Applying temporal filtering and nuisance regression..."
echo "  Calculating temporal mean..."
fslmaths func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
         -Tmean func/${FULLID_folder}/temporal_filtering/${FULLID_file}_tempMean_func.nii.gz &&\

echo "  Performing temporal regression and demeaning..." &&\
fsl_glm -i func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz \
        -d ${nuisance_file} \
        --demean \
        --out_res=func/${FULLID_folder}/temporal_filtering/${FULLID_file}_residual.nii.gz &&\

# Determining TR
echo "  Setting the bptf value..." &&\
TR=$(fslval func/${FULLID_folder}/ICA_AROMA/denoised_func_data_nonaggr.nii.gz pixdim4) &&\

# Calculating the highpass temporal filter cut-off
bptf=$(python -c "print(100/$TR)") &&\

echo "  Performing highpass filtering and adding temporal mean back again..." &&\
fslmaths func/${FULLID_folder}/temporal_filtering/${FULLID_file}_residual.nii.gz \
         -bptf $bptf \
         -1 \
         -add func/${FULLID_folder}/temporal_filtering/${FULLID_file}_tempMean_func.nii.gz \
         func/${FULLID_folder}/temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz &&\

#create symbolic link with easier-to-find filename
ln -s temporal_filtering/${FULLID_file}_denoised_func_data_nonaggr_hptf_func.nii.gz \
      func/${FULLID_folder}/${FULLID_file}_preprocessed_func.nii.gz &&\

printf "\n\n$(date)\n#### Done! ####\n"