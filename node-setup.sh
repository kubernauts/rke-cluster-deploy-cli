#!/usr/bin/env bash

# ==============  emojis   ===============
UNICORN='\360\237\246\204'
FOLDINGHANDS='\xF0\x9F\x99\x8F'
NOEVELMONKEY='\xF0\x9F\x99\x88'
CHECKMARK='\xE2\x9C\x85'

set -oe pipefail

# ===========   user inputs   ============
nodeUsr='nfio3'
read -p  "Please provide the nodes user!(default: ${nodeUsr}) promt with [ENTER]:" inputUsr
nodeUsr="${inputUsr:-$nodeUsr}"
read -p  "Please provide the nodes password! promt with [ENTER]:" nodePW

# ======= load nodes from files ==========
NODES = echo $(cat nodelist.txt)
if [ ${NODES} -lt 2]; then 
  printf "[${NOEVELMONKEY}] no nodes found" ; exit
fi

for NODE in ${NODES}; do
  printf "setup and check node: ${NODE}"

  # ======================================
  # =========   copy rsa token   =========
  # ======================================

  sshpass -p ${nodePW} ssh-copy-id -i ./rancher-rke-key.pem ${nodeUsr}@${NODE}

  # =========   ssh into node   ==========
  ssh ${nodeUsr}@${NODE}

  # ======================================
  # ========= application checks =========
  # ======================================

  if hash kubectl &> /dev/null; then
    printf "[${UNICORN}] kubectl is available" 
  else
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      printf "[${NOEVELMONKEY}] kubectl not installed"
      printf "try to install kubectl for ubuntu"

      ksudo apt-get update && sudo apt-get install -y apt-transport-https
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
      printf "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubectl
    fi
      printf "[${CHECKMARK}] success"
  fi

  # ======================================
  # ========= docker permissions =========
  # ======================================

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    printf "linux os detected"
    if id | grep docker; then
      printf "user is in systemgroup docker ${UNICORN}"
    else
      printf "user is not in systemgroup docker ${NOEVELMONKEY}"
      printf "adding user to group docker"

      sudo usermod -aG docker $USER
      newgrp docker 
    fi
      printf "[${CHECKMARK}] success"
  fi
done