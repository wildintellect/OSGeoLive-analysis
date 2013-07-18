#!/bin/bash

# http://stackoverflow.com/a/283168/237354
# history_of_file
#
# Outputs the full history of a given file as a sequence of
# logentry/diff pairs.  The first revision of the file is emitted as
# full text since there's not previous version to compare it to.

function history_of_file() {
    url=$1 # current url of file
    svn log -r $revStart:$revEnd -q $url$revEnd | grep -E -e "^r[[:digit:]]+" -o | cut -c2- | sort -n | {
    #svn log -q $url | grep -E -e "^r[[:digit:]]+" -o | cut -c2- | sort -n | {

#       first revision as full text
        echo $r
        read r
        #svn log -r$r $url$revEnd >> replay/$url-timestamps.txt
        svn cat -r$r $url$revEnd > replay/$r-$url
        #echo

#       remaining revisions as differences to previous revision
        while read r
        do
            echo $r
            #svn log -r$r $url$revEnd >> replay/$url-timestamps.txt
#           svn diff -c$r $url@HEAD
	        svn cat -r$r $url$url$revEnd > replay/$r-$url 
            #echo
        done
    }
}

revStart=$2
# TODO: if not arg 3 use @HEAD
revEnd=@$3
history_of_file $1

#Get list of all revision timestamps
svn log -q > replay/svn-revisions.txt
