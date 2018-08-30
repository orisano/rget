#!/bin/sh
set -e
WORKDIR=`mktemp -d`

PROCESS=4
BLOCKSIZE=8388608
while getopts "P:b:o:u:" OPTION
do
  case $OPTION in
    P) PROCESS=${OPTARG};;
    b) BLOCKSIZE=${OPTARG};;
    o) OUTPUT=${OPTARG};;
    *) exit $E_OPTERROR;;
  esac
done
shift $(($OPTIND - 1))

CONTENT_LENGTH=`curl -IsSL -X GET $1 | grep Content-Length: | awk '$0=$2'`
echo $CONTENT_LENGTH
seq 0 $BLOCKSIZE $CONTENT_LENGTH | awk -v BS=$BLOCKSIZE -v WD=$WORKDIR '{print "-SsL -r " sprintf("%d-%d", $0, $0 + BS - 1) " -o " sprintf("%s/%05d", WD, NR)}' | xargs -n 5 -P $PROCESS -I{} sh -c "curl {} $1"
cat $WORKDIR/* > $OUTPUT
rm -rf $WORKDIR
