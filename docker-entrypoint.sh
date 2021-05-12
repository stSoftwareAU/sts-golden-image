#!/usr/bin/env sh
set -ex

function doInit()
{
  if test -f "store/terraform.tfstate"; then
      cp store/*.tfstate .
  fi
}

function doStore()
{
  cp *.tfstate store/
}

function doApply()
{
  doInit

  terraform init -input=false
  terraform validate
  terraform plan -input=false -out=tf.plan
  terraform apply -auto-approve -input=false tf.plan

  doStore
}

function doDestroy()
{
    doInit
    terraform init -input=false
    terraform destroy -auto-approve -input=false 
    doStore
}

mode="apply"
# handle non-option arguments
if [[ $# -eq 1 ]]; then
  mode=$1
elif [[ $# -gt 1 ]]; then
  echo "$0: A maximum of one argument is expected"
  exit 4
fi

case "$mode" in
  shell)
    /bin/sh
    ;;
  apply)
    doApply
    ;;
  destroy)
    doDestroy
    ;;
  *)
    echo "${mode}: Unknown mode"
    exit 5
    ;;
esac