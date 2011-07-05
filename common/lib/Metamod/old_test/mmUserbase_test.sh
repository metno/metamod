#!/bin/bash
cat >mmUserbase_usage <<EOF

 Test script for mmUserbase.pm

 *********************************************************************
 *                                                                   *
 * NOTE: THIS SCRIPT RE-INITIALIZE THE USER DATABASE. MUST NOT BE    *
 *       RUN IN A PRODUCTION ENVIRONMENT.                            *
 *                                                                   *
 *********************************************************************

 The script will run the ../../../userinit/run_createuserdb.sh script if it exists.

 This script is a wrapper around the mmUserbase_test.pl script that creates a mmUserbase.pm
 object and perform method calls to this object taken from the mmUserbase_commands file.
 The perl script writes the method calls to standard output together with the response from
 the mmUserbase.pm object.

 Usage:

     mmUserbase_test.sh --new >./mmUserbase_test_out

        Creates a new version of the output file that later test runs will be compared to.
        This has to be done each time changes are done to mmUserbase.pm, mmUserbase_test.pl
        or mmUserbase_commands that will involve intended changes to the standard output.

     mmUserbase_test.sh --run

        Runs mmUserbase_test.pl and checks if the output is the same as that contained in the
        mmUserbase_test_out file. Writes "OK" to standard output if this is the case.
        Otherwise, writes a diff between the mmUserbase_test_out file and this output.

EOF
arg='none'
if [ $# -eq 1 ]; then
    if [ $1 = '--new' ]; then
       arg=$1
    elif [ $1 = '--run' ]; then
       arg=$1
    fi
fi
if [ $arg = 'none' ]; then
    cat mmUserbase_usage
    rm mmUserbase_usage
    exit
fi
rm mmUserbase_usage
if [ -x '../../../userinit/run_createuserdb.sh' ]; then
    thisdir=`pwd`
    cd ../../../userinit
    ./run_createuserdb.sh
    cd $thisdir
else
    echo "\nWorks only on installed METAMOD instances using the BASE module\n"
    exit
fi
if [ $arg = '--new' ]; then
    ./mmUserbase_test.pl
fi
if [ $arg = '--run' ]; then
    ./mmUserbase_test.pl | diff - ../../../htdocs/funcs/test/mmUserbase_test_out >mmUserbase_diff
    if [ -s mmUserbase_diff ]; then
        echo ""
        echo "Unexpected output. Diff between ./mmUserbase_test_out and this output:"
        echo ""
        cat mmUserbase_diff
        echo ""
    else
        echo "OK"
    fi
    rm mmUserbase_diff
fi
