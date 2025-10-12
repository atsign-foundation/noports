#!/bin/bash

sleep 2
echo "State	Session"
echo "=====	======="
while read -r line || [[ -n $line ]];
do
  sessionId=$(jq -r '.sessionId' <<< "$line")
  sessionState=$(jq -r '.state' <<< "$line")
  extendedJson='{"doc":'$line',"doc_as_upsert":true}'

  echo "$sessionState	$sessionId"
  curlOutput=$(curl -s -S \
    -X POST "http://localhost:9200/noports/_update/$sessionId" \
    -H "Content-Type: application/json" \
    -d "$extendedJson")
  curlExitCode=${PIPESTATUS[0]}
  if [ "$curlExitCode" != 0 ] ; then
      echo curl exitCode: "$curlExitCode" output: "$curlOutput"
  fi
done

