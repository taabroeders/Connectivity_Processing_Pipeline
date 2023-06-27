#!/bin/bash

[ -f $0/files/ICA-AROMA/ICA_AROMA.py ] || git submodule update --init --recursive

[ -f $0/files/singularity/synbold-disco.sif] || singularity pull $0/files/singularity/synbold-disco.sif docker://ytzero/synbold-disco:v1.4

[ -f $0/files/singularity/synb0-disco.sif ] || singularity pull $0/files/singularity/synb0-disco.sif docker://leonyichencai/synb0-disco:v3.0