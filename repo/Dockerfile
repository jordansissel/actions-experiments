FROM ubuntu:latest

RUN apt-get update && apt-get install -y reprepro gnupg debsigs createrepo-c rpm jq

COPY update.sh /tmp/update.sh
