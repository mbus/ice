#!/bin/bash

# Andrew Lukefahr
# lukefahr@umich.edu

# find all folders
DIRS=$(find . -maxdepth 1 -mindepth 1 -type d -exec echo {} \;)

for DIR in $DIRS
do
    echo "Working on $DIR"

    # enter dir
    cd $DIR
    
    # compile
    make > make.out 2>make.err

    # run the test
    PASS_CHECK=$(grep '@@@' make.out)
    if [ "$PASS_CHECK" == "@@@Passed" ]; then
        echo "PASSED: $PASS_CHECK"
    else 
        echo "FAILED: $PASS_CHECK"
    fi
   
    # cleanup
    rm make.out
    rm make.err

    # backup 
    cd ..
done
