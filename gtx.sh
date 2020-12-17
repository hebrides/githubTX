#!/bin/bash
#
# 
#    Refactored from script by Douglas C. Ayers:
#
#    https://gist.github.com/douglascayers/9fbc6f2ad899f12030c31f428f912b5c#file-github-copy-labels-sh
#
#
#
#
# This script uses the GitHub REST API v3
# https://docs.github.com/en/free-pro-team@latest/rest/overview
# https://developer.github.com/v3/issues/milestones/#create-a-milestone
# https://developer.github.com/v3/issues/labels/#create-a-label
# https://developer.github.com/v3/issues/#create-an-issue
# https://developer.github.com/v3/projects/cards/#create-a-project-card
#

# Provide a personal access token that can
# access the source and target repositories.
# This is how you authorize with the GitHub API.
# https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line



#   Uses optional config file: gtx.config, e.g.
#
#   GH_TOKEN=9043JGJ8492GHRW874ADFAD
#   SRC_GH_USER=rockingcodeninja1999
#   SRC_GH_REPO=myoldproject
#   TGT_GH_USER=rockingcodeninja1999
#   TGT_GH_REPO=mynewproject
#

printf "
########################### GitHub Transfer ############################

    NOTE: If you use GitHub Enterprise, please update this script.

########################################################################
"

clear 

# Check jq
if ! type "jq" > /dev/null
then
  printf "\n>> ERROR: Requires jq (https://stedolan.github.io/jq/): brew install jq\n\n"
  exit 1
fi

# If you use GitHub Enterprise, change this to "https://<your_domain>/api/v3"
GH_DOMAIN="https://api.github.com"

if [ -f gtx.config ]
then
    # Read config
    printf "\n>> Using configuration file\n"
    source gtx.config
else 
    read -p "Enter your GitHub token (ref: https://tinyurl.com/yxmect7t): " GH_TOKEN 
    # The source repository from which to copy.
    read -p "Source GitHub user ID (e.g. hebrides): " SRC_GH_USER
    read -p "Source repo name (e.g. smartbar): " SRC_GH_REPO

    # The target repository to which add or update.
    read -p "Target GitHub user ID: " TGT_GH_USER
    read -p "Target repo name: " TGT_GH_REPO
fi

# Check if correct vars set and not empty
if [ -z ${GH_TOKEN} ] || [ -z ${SRC_GH_USER} ] || [ -z ${SRC_GH_REPO} ] || [ -z ${TGT_GH_USER} ] || [ -z ${TGT_GH_REPO} ]
then
    printf "\n>> ERROR: Input contains missing or empty parameter. Please try again.\n\n"
    exit 1
fi  


# ---------------------------------------------------------

# Headers used in curl commands
# accept:
# application/vnd.github.v3+json 
# application/vnd.github.symmetra-preview+json 
# application/vnd.github.inertia-preview+json <-- Must use for projects

GH_ACCEPT_HEADER="Accept: application/vnd.github.v3+json"
GH_AUTH_HEADER="Authorization: Bearer $GH_TOKEN"

# Bash for-loop over JSON array with jq
# https://starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
sourceItemsJson64=$(curl --silent -H "$GH_ACCEPT_HEADER" -H "$GH_AUTH_HEADER" ${GH_DOMAIN}/repos/${SRC_GH_USER}/${SRC_GH_REPO}/issues?per_page=100 | jq '[ .[] | { "title": .title, "body": .body, "assignees": .assignees, "milestone": .milestone, "labels": .labels  } ]' | jq -r '.[] | @base64' )

# for each postable item from source repo,
# invoke github api to create or update
# the item in the target repo
count=0
for sourceItemJson64 in $sourceItemsJson64; do

    # base64 decode the json
    sourceItemJson=$(echo ${sourceItemJson64} | base64 --decode | jq -r '.')

    # try to create the item
    # POST /repos/:owner/:repo/{item}s { param 1, param 2, param 3, ... }
    createItemResponse=$(echo $sourceItemJson | curl --silent -X POST -d @- -H "$GH_ACCEPT_HEADER" -H "$GH_AUTH_HEADER" ${GH_DOMAIN}/repos/${TGT_GH_USER}/${TGT_GH_REPO}/issues)

    # if creation failed then the response doesn't include an id and jq returns 'null'
    createdItemId=$(echo $createItemResponse | jq -r '.id')

    # if item wasn't created maybe it's because it already exists, try to update it
    if [ "$createdItemId" == "null" ]
    then
        updateItemResponse=$(echo $sourceItemJson | curl --silent -X PATCH -d @- -H "$GH_ACCEPT_HEADER" -H "$GH_AUTH_HEADER" ${GH_DOMAIN}/repos/${TGT_GH_USER}/${TGT_GH_REPO}/issues/$(echo $sourceItemJson | jq -r '.id | @uri'))
        echo "Update item response:"
        echo $updateItemResponse
    else
        echo "Create item response:"
        echo $createItemResponse
    fi
    ((count++))
    if [ $((count%8)) -eq 0 ]
    then
        echo "Pausing to breathe..."
        sleep 10
    fi

done
