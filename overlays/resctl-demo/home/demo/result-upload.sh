#!/bin/bash
# Copyright © 2023 Collabora Ltd.
# SPDX-License-Identifier: MIT

if [[ $# -ne 2 ]]; then
  echo >&2 " Error: Wrong number of arguments"
  echo >&2 " result-upload.sh  <RESULT FILE>  <SERVER URL>"
  exit 1
fi

RESULT_JSON=$1
SERVER_URL=$2

ping -c 1 -w 100 -q github.com >&/dev/null

if ! [[ $? == 0 ]] ; then
  nmtui
  ping -c 1 -w 100 -q github.com >&/dev/null
  if [[ $? == 0 ]] ; then
    echo "Network connected"
  else
    echo >&2 "Network not connected"
    exit 1
  fi
else
  echo "system is online"
fi

echo "Upload benchmark result...."

curl --upload-file "$RESULT_JSON" "$SERVER_URL"

if [[ $? -ne  0 ]]; then
  echo >&2 "Failed to upload benchmark result"
else
  echo "Successfully uploaded benchmark result"
fi
