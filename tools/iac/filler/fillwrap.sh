#!/bin/bash
# Wrap fillOut.js to help with return values and the like
# Argument 1 is the PDF to fill
# Argument 2 is the BP-01 path
# Argument 3 is where to write the output
# NODE_RUN_CMD is a required environment variable to tell where the node runtime is

pdf_path=$1
bp01_path=$2
final_path=$3
my_path=`dirname $0`
node_ret=0

if [[ $DEBUG == 1 ]];
then
    echo pdf_path=${pdf_path}
    echo bp01_path=${bp01_path}
    echo final_path=${final_path}
    echo my_path=${my_path}
else
    # Flatten the PDF before writing to it
    ${PDFTK_RUN_CMD} ${pdf_path} output ${pdf_path}-flatten.pdf flatten

    export PDFTK_RUN_CMD=${PDFTK_RUN_CMD}
    # Execute the complex pipeline
    cat ${pdf_path}-flatten.pdf| \
        ${NODE_RUN_CMD} ${my_path}/fillOut.js ${bp01_path} > \
        ${final_path}

    rm ${pdf_path}-flatten.pdf

    node_ret=$?
fi

# Pass return value
exit $node_ret
