#! /usr/bin/bash

mkdir $1
cd $1
mkdir sublist3r


#-----------------------grabbing subdomains-----------------------
subfinder -dL ../wildcards -o subfinder.out #subfinder
findomain -f ../wildcards --unique-output findomain.out #findomain
cat ../wildcards | assetfinder --subs-only > assetfinder.out #assetfinder

#sublist3r
while read -r url
do sublist3r -d "$url" -o "sublist3r/${url}.out"
done < wildcards #sublister on all domains
cat subfinder.out findomain.out assetfinder.out | sort -u > allsubs.out #collecting all subdomains in one file
#-----------------------grabbing subdomains-----------------------

#httpx-tool
httpx-toolkit -l allsubs.out -sc -td -probe -server -x 'all' -o httpxtool.out
cat httpxtool.out | grep -i nginx > nginx
cat httpxtool.out | grep -i apache > apache
cat httpxtool.out | grep SUCCESS | cut -d " " -f 1 | sort -u > SUCCESS.out

#katana
katana -u SUCCESS.out -jc -d 10 -jsluice -silent

#extracting only js files urls
cat katana.out | grep '\.js$' > onlyjsfiles

#secretFinder
while read -r url2
do python3 /tools/recon/SecretFinder/SecretFinder.py -i "$url2" -o secretfinder.html
done < onlyjsfiles



#nuclei -l allsubs.out -o nuclei.out
