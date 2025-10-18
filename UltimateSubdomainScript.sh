#! /usr/bin/bash

mkdir $1
cd $1
mkdir sublist3r

subfinder -dL ../wildcards -o subfinder.out #subfinder
findomain -f ../wildcards --unique-output findomain.out #findomain
cat ../wildcards | assetfinder --subs-only > assetfinder.out #assetfinder
while read -r url; do sublist3r -d "$url" -o "sublist3r/${url}.out" done < wildcards #sublister on all domains
cat subfinder.out findomain.out assetfinder.out | sort -u > allsubs.out #collecting all subdomains in one file
httpx-toolkit -l allsubs.out -sc -td -probe -server -x 'all' -o httpxtool.out
cat httpxtool.out | grep -i nginx > nginx
cat httpxtool.out | grep -i apache > apache
cat httpxtool.out | grep SUCCESS | cut -d " " -f 1 | sort -u > SUCCESS.out

katana -u SUCCESS.out -jc -hl 


#nuclei -l allsubs.out -o nuclei.out
