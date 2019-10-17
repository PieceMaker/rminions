#!/bin/bash
r -e "library(rminions); minionWorker(host = \"$REDIS\", port = $PORT, jobsQueue = \"$QUEUE\", useJSON = as.logical(tolower(\"$USEJSON\")));"
