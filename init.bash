#!/bin/bash

module load Anaconda3/2023.03

[ -d $(dirname $0)/files/ICA-AROMA ] || git submodule update --init --recursive

[ -d $(dirname $0)/files/niftyseg ] || git submodule update --init --recursive

[ -d $(dirname $0)/files/MRtrix3Tissue ] || git submodule update --init --recursive

[ -f $(dirname $0)/files/singularity/synbold-disco.sif ] || singularity pull $(dirname $0)/files/singularity/synbold-disco.sif docker://ytzero/synbold-disco:v1.4

[ -f $(dirname $0)/files/singularity/synb0-disco.sif ] || singularity pull $(dirname $0)/files/singularity/synb0-disco.sif docker://leonyichencai/synb0-disco:v3.0

[ -d $(dirname $0)/files/preproc_env_ica ] || conda env create --prefix $(dirname $0)/files/preproc_env -f $(dirname $0)/files/environment_ica.yml