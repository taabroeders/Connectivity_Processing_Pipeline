#!/bin/bash

[ -f $(dirname $0)/files/ICA-AROMA/ICA_AROMA.py ] || git submodule update --init --recursive

[ -f $(dirname $0)/files/singularity/synbold-disco.sif ] || singularity pull $(dirname $0)/files/singularity/synbold-disco.sif docker://ytzero/synbold-disco:v1.4

[ -f $(dirname $0)/files/singularity/synb0-disco.sif ] || singularity pull $(dirname $0)/files/singularity/synb0-disco.sif docker://leonyichencai/synb0-disco:v3.0

[ -d $(dirname $0)/files/preproc_env ] || conda env create --prefix $(dirname $0)/files/preproc_env -f $(dirname $0)/files/environment.yml