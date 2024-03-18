#!/bin/bash

#======================================================================
#                         Check Modules
#======================================================================

#@author: Tommy Broeders
#@email:  t.broeders@amsterdamumc.nl
#updated: 15 03 2023
#status: finished

#Review History
#Reviewed by -

# Description:
# - This code is part of the "KNW-Connect Processing Pipeline".
#   It will load neccesary modules.
#
# - Prerequisites: None
# - Input:
# - Output:
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#                           Adapt if needed
#----------------------------------------------------------------------
module load fsl/6.0.6.4
module load FreeSurfer/7.3.2-centos8_x86_64
module load ANTs/2.4.1
module load art/2.1
module load Anaconda3/2023.03
module load GCC/9.3.0
module load OpenMPI/4.0.3
module load MRtrix/3.0.3-Python-3.8.2