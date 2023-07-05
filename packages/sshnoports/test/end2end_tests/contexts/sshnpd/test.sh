#!/bin/bash
# this is script is meant to be run by the sshnp container.
# cat test.txt and check if "test passed" exit 0, otherwise exit 1
cat test.txt | grep "Test Passed"
if [ $? -eq 0 ]
then
    echo "Test Passed"
    exit 0
fi
echo "Test Failed"
exit 1