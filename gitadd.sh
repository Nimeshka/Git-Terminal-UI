#!/usr/bin/env bash

# Description: A really simple terminal gui for repetitive git commands.
# Author: Nimeshka Srimal
# Version: 1.0.0

# Override the color scheme..
export NEWT_COLORS='
  window=,brightblue
  border=gray,gray
  textbox=gray,lightgray
  button=gray,white
  active button=white,gray
  shadow=,blue
  roottext=brightblue,gray
'

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[0;1m'
RC='\033[0m' # Reset

while IFS= read -ra line ; do

    if [[ ! $line = *"not a git repository"* ]]; then
       
        # unstaged files are returned with a leading space in the file name...so we check for that to identify unstaged files
        # we also need to list untracked files which are denoted with ??
        if [[ "$line" =~ ^(\ |"??").*$ ]]; then

            # break the filename into chunks by space.
            IFS=' ' read -ra fname <<< $line

            # remove the leading file status indicator.
            status=${fname[0]}

            case ${fname[0]} in
                "D") 
                    status="[Deleted]"
                ;;
                "??") status="[Untracked]"
                ;;
                "A") status="[New]"
                ;;
                "M") status="[Modified]"
                ;;
                *)
                status=${fname[0]}
                ;;
            esac

            unset 'fname[0]' 

            # remove the leading and ending quotation marks from all files.
            filename=$(echo ${fname[*]} | sed 's/^"\(.*\)"$/\1/')

            # if the filename has a space in it, wrap it with single quotes, and then with double quotes, ex: "'file name'" => return 'file name'
            # to preserve the single quote in return value of whiptail.
            if [[ $filename = *" "* ]]; then
                filename="\"'$filename'\""
            fi

            filelist=$filelist' '$filename' '$status' off'
        else
            otherfilelist=$otherfilelist$line
        fi
    else
        echo '+----------------------+'
        echo "| Not a git repository |"
        echo '+----------------------+'
        exit
    fi
done <<< "$(git status --porcelain 2>&1)"


if [ -z "$filelist" ] && [ -z "$otherfilelist" ]; then
    echo '+---------------------------------------+'
    echo "| Nothing to commit, working tree clean |"
    echo '+---------------------------------------+'

    exit;

elif [ -z "$filelist" ] && [ ! -z "$otherfilelist" ]; then
    echo '+---------------------------------------------------------+'
    echo "| Nothing to stage. Commit the files in the staging area |"
    echo '+---------------------------------------------------------+'

    git status
    exit;

fi

branchname="["`git branch | grep '^*'`"]"

# define the whiptail checklist command to run.
whipcommand='whiptail --separate-output --title "Select files to stage '$branchname'" --checklist " " 20 60 10 '$filelist' 3>&1 1>&2 2>&3'

filestoadd=$(eval "$whipcommand")

if [ -z "$filestoadd" ]; then
    echo '+-------------------+'
    echo "| Nothing selected! |"
    echo '+-------------------+'
    exit;
else
    # replace the new line with a space.
    filestoadd=$(echo "$filestoadd"|tr '\n' ' ')
fi

# we have to add the files now..
gitadd="git add "$filestoadd

if eval "$gitadd"; then

    # stage sucess...prompt the user for commit?
    whiptail --yesno "Files staged successfully. Do you want to commit now?" 10 60

    if [ "$?" -eq 0 ] ; then
   
        # Answer to commit: Yes. So we get the commit message from user.
        commitmsg=$(whiptail --title "Commit" --inputbox "Please enter commit message" 10 60 3>&1 1>&2 2>&3)
    
        if [ "$?" = 0 ] && [ ! -z "$commitmsg" ]; then

            # replace any quotes because it breaks the commit.
            if eval "git commit -m '"${commitmsg//\'/\\}"'"; then
            
                echo '+-----------------+'
                printf "| ${GREEN}Commit success!${RC} |\n"
                echo '+-----------------+'
                
            else
                echo '+----------------+'
                printf "| ${RED}Commit failed!${RC} |\n"
                echo '+----------------+'

            fi
        else
            echo '+-------------------+'
            printf "| ${RED}Commit cancelled!${RC} |\n"
            echo '+-------------------+'
        fi
    fi

else
    echo '+-----------------------------------------+'
    printf "| ${RED}Failed to add files to the staging area${RC} |\n"
    echo '+-----------------------------------------+'
    exit; 
fi