#!/bin/bash
DATAPATH=$1
OUTDIR=$2


for FQ1 in ${DATAPATH}/*R1_001.fastq.gz
do
    FQ2=${FQ1/R1/R2}
    cutadapt -j 20 -m 15 -O 5 -n 3 -q 20 \
         -b AAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC \
         -B GATCGTCGGACTGTAGAACTCTGAACGTGTAGA \
         -o ${OUTDIR}/TRIMMED_$(basename ${FQ1}) -p ${OUTDIR}/TRIMMED_$(basename ${FQ2}) \
         ${FQ1} ${FQ2}
done
