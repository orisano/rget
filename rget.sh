#!/bin/sh
set -e

PROCESS=4
BLOCKSIZE=8388608
while getopts "P:b:o:" OPTION
do
  case $OPTION in
    P) PROCESS=${OPTARG};;
    b) BLOCKSIZE=${OPTARG};;
    o) OUTPUT=${OPTARG};;
    *) exit 2;;
  esac
done
shift $(($OPTIND - 1))

WORKDIR=`mktemp -d`

CONTENT_LENGTH=`wget --spider -S ${1} 2>&1 | grep Content-Length | awk '$0=$2'`
seq 0 $BLOCKSIZE $(($CONTENT_LENGTH - 1)) | awk -v BS=$BLOCKSIZE -v WD=$WORKDIR '{f=sprintf("%s/%05d",WD,NR);printf("echo > %s && wget -q -c --header \"Range: bytes=%d-%d\" -O %s\n", f, $0, $0 + BS - 1, f)}' | xargs -n 12 -P ${PROCESS} -I{} sh -c "{} $1"
for f in $WORKDIR/*; do
    tail -c +2 $f >> $OUTPUT
done
rm -rf $WORKDIR
