#!/usr/bin/env python



from collections import defaultdict
import os

#raw_data_path = '/stor/scratch/Lambowitz/cdw2854/bench_marking/data'
raw_data_path = '/mnt/scratch6/hirak/SLA_benchmark/tgirt_experiment/RNA_seq/'
aspera_binary = "/home/hirak/.aspera/connect/bin/ascp"
aspera_key = "/home/hirak/.aspera/connect/etc/asperaweb_id_dsa.openssh"

sample_dict = defaultdict(int)

def prepareURL(srr_name, prefix="era-fasp@fasp.sra.ebi.ac.uk:/vol1/fastq/"):
    dir_1=srr_name[:6]
    dir_2=""
    url=""
    num_digits=sum(s.isdigit() for s in srr_name)
    if(num_digits == 6):
        url=prefix+dir_1+"/"+srr_name+"/"
    elif(num_digits == 7):
        dir_2="00"+srr_name[-1]
        url=prefix+dir_1+"/"+dir_2+"/"+srr_name+"/"
    elif(num_digits == 8):
        dir_2="0"+srr_name[-2:]
        url=prefix+dir_1+"/"+dir_2+"/"+srr_name+"/"
    elif(num_digits == 9):
        dir_2=srr_name[-3:]
        url=prefix+dir_1+"/"+dir_2+"/"+srr_name+"/"
    return url

'''
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--SRR', help='SRR name to be parsed')
    parser.add_argument('--file', help='file containing SRR name to be parsed')
    args = parser.parse_args()
    if args.file:
        with open(args.file) as srr_file:
            for line in srr_file:
                url = prepareURL(line.strip())
                print("{}*.fastq.gz".format(url))
    else:
        url = prepareURL(args.SRR)
        print("{}*.fastq.gz".format(url))
'''

with open('command.sh','r') as table:
    for i, line in enumerate(table):
        fields = line.split(' ')
        run_number = fields[2]
        url = prepareURL(run_number)
        #srr_dir = '/'.join([raw_data_path,run_number])
        #render commands
        '''
        download_command = 'fastq-dump --split-3 --gzip --outdir %s %s ' %(raw_data_path, run_number)
        rename_read1_command = 'mv %s/%s_1.fastq.gz %s/%s_R1_001.fastq.gz' \
                %(raw_data_path,run_number, raw_data_path, sample_id)
        rename_read2_command = 'mv %s/%s_2.fastq.gz %s/%s_R2_001.fastq.gz' \
                %(raw_data_path,run_number, raw_data_path, sample_id)
        '''
        print("{} -P 33001 -QT -l 1000m -i {} {} {}".format(aspera_binary, aspera_key, url, raw_data_path))
        os.system("{} -P 33001 -QT -l 1000m -i {} {} {}".format(aspera_binary, aspera_key, url, raw_data_path))
        #print ';'.join([download_command, rename_read1_command, rename_read2_command])
