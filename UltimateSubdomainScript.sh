#! /usr/bin/bash

mkdir $1
cd $1

subfinder -dL ../wildcards -o subfinder.out #subfinder
findomain -f ../wildcards --unique-output findomain.out #findomain
cat ../wildcards | assetfinder --subs-only > assetfinder.out #assetfinder
sublist3r -d $1 -o sublist3r.out #sublist3r
cat subfinder.out findomain.out assetfinder.out > allsubs.out #collecting all subdomains in one file

httpx-toolkit -l allsubs.out -sc -td -probe -server -o httpxtool.out
