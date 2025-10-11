#!/bin/bash

sleep 2
echo "State	Session"
echo "=====	======="
while read -r line || [[ -n $line ]];
do
  sessionId=$(jq -r '.sessionId' <<< $line)
  sessionState=$(jq -r '.state' <<< $line)
  extendedJson='{"doc":'$line',"doc_as_upsert":true}'

  echo "$sessionState	$sessionId"
  echo "		$line"
  curlOutput=$(curl -s \
    -X POST "http://localhost:9200/noports/_update/$sessionId" \
    -H "Content-Type: application/json" \
    -d "$extendedJson")
  curlExitCode=$?
  if [ $curlExitCode != 0 ] ; then
      echo curl exitCode $curlExitCode; error: "$curlOutput"
      exit $curlExitCode
  fi
done

