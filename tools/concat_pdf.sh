#!/bin/bash

pdf_path=$1
final_path=$2

# Execute the merge
${IAC_PDFTK_RUNCMD} ${pdf_path} output ${final_path}

