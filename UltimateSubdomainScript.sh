#! /usr/bin/bash

mkdir $1
cd $1
mkdir sublist3r

#-----------------------grabbing wildcards-----------------------#
python3 /root/BugHunting/ctfr/ctfr.py -d "$url" -o wildcards_ctrf.out
cat  wildcards_ctrf.out | grep '*' | cut -d "*" -f 2 | sed 's/\.//' >> wildcards
#-----------------------grabbing wildcards-----------------------#

#-----------------------grabbing subdomains-----------------------#
subfinder -dL wildcards -o subfinder.out #subfinder
findomain -f wildcards --unique-output findomain.out #findomain
cat wildcards | assetfinder --subs-only > assetfinder.out #assetfinder
gobuster dns --domain "$url" -w /usr/share/seclists/Discovery/DNS/ALL_SUBDOMAINS.txt -q -o gobuster_brute.out
#sublist3r
while read -r url
do sublist3r -d "$url" -o "sublist3r/${url}.out"
done < wildcards #sublister on all domains
cat subfinder.out findomain.out assetfinder.out sublist3r/*.out gobuster_brute.out  | sort -u > allsubs.out #collecting all subdomains in one file
#-----------------------grabbing subdomains-----------------------#

#httpx-tool
httpx-toolkit -l allsubs.out -sc -td -probe -server -x 'all' -o httpxtool.out
cat httpxtool.out | grep SUCCESS | cut -d " " -f 1 | sort -u > SUCCESS.out

#-----------------------NUCLEI SCAN-----------------------#
nuclei -l SUCCESS.out -o nuclei.out
#-----------------------NUCLEI SCAN-----------------------#
