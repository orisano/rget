#!/bin/sh
set -e

URL=
OUTPUT=
PROCESS=4
BLOCK_SIZE=

usage() {
    echo "Usage: rget.sh -o OUTPUT -u URL [-P PROCESS] [-b BLOCK_SIZE]" >&2
}

while getopts "o:u:P:b:" OPTION
do
  case ${OPTION} in
    o) OUTPUT=${OPTARG};;
    u) URL=${OPTARG};;
    P) PROCESS=${OPTARG};;
    b) BLOCK_SIZE=${OPTARG};;
    *) usage; exit 2;;
  esac
done

[ -z ${OUTPUT} ] && { usage; echo "OUTPUT must be required" >&2; exit 2; }
[ -z ${URL} ] && { usage; echo "URL must be required" >&2; exit 2; }

WORK_DIR=`mktemp -d`
atexit() {
    rm -rf ${WORK_DIR} || true
}
trap 'rc=$?; trap - EXIT; atexit; exit $?' INT PIPE TERM
trap atexit EXIT

CONTENT_LENGTH=`wget --spider -S ${URL} 2>&1 | grep Content-Length | awk '$0=$2'`
[ -z ${BLOCK_SIZE} ] && BLOCK_SIZE=$(( (${CONTENT_LENGTH} + ${PROCESS} - 1) / ${PROCESS} ))

GEN_PARAM=`cat<<'EOF'
{
    block_path = sprintf("%s/%05d", WORK_DIR, NR);
    printf("echo > %s", block_path);
    printf(" && ");
    printf("wget -q -c --header \"Range: bytes=%d-%d\" -O %s", $0, $0 + BLOCK_SIZE - 1, block_path)
    printf("\n");
}
EOF`

seq 0 ${BLOCK_SIZE} $((${CONTENT_LENGTH} - 1)) | awk -v BLOCK_SIZE=${BLOCK_SIZE} -v WORK_DIR=${WORK_DIR} "${GEN_PARAM}" | xargs -n 12 -P ${PROCESS} -I{} sh -c "{} ${URL}"

rm -rf ${OUTPUT} || true
for block in ${WORK_DIR}/*; do
    dd if=${block} skip=1 iflag=skip_bytes bs=${BLOCK_SIZE} 2>/dev/null >> ${OUTPUT}
done
