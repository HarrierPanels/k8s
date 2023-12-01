#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  CMD="sudo"
else
  CMD=""
fi

BASE_URL="https://raw.githubusercontent.com/HarrierPanels/k8s/main"
SCRIPTS=("install-docker.sh" "install-nginx.sh" "install-playpit.sh")

for SCRIPT in "${SCRIPTS[@]}"; do
  curl -s "${BASE_URL}/${SCRIPT}" | ${CMD} bash
done
