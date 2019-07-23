#!/bin/bash
r -e "library(rminions); minionWorker(host = \"$REDIS\", jobsQueue = \"$QUEUE\");"