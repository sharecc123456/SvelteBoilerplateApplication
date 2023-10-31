#!/bin/bash

filepath=$1
finalpath=$2

# Execute the merge
${IAC_CONVERT_IMAGE_RUNCMD} "$filepath" "$finalpath"
