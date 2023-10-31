#!/bin/bash
# Wrap fillAppendix.js to help with return values and the like
# Argument 1 is the JSON APX
# Argument 2 is where to write the output
# PYTHON_RUN_CMD is a required environment variable to tell where the node runtime is

apx_path=$1
final_path=$2
my_path=`dirname $0`
node_ret=0

if [[ $DEBUG == 1 ]];
then
    echo apx_path=${apx_path}
    echo final_path=${final_path}
    echo my_path=${my_path}
else
    # Execute the complex pipeline
    ${PYTHON_RUN_CMD} ${my_path}/fillAppendix.py ${apx_path} ${final_path}
    node_ret=$?
fi

# Pass return value
exit $node_ret
