#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"
. ./init.sh

source environment.properties

mode="import"

tag="dta-iac/goldern-image"

store_dir=$(mktemp -d -t tf_XXXXXXXXXX)

s3_bucket=`echo "${DEPARTMENT}-${AREA}-v4"|tr "[:upper:]" "[:lower:]"`
LIST_BUCKETS=`aws s3api list-buckets`

s3_store="${s3_bucket}/${tag}/store"

aws s3 cp s3://${s3_store} ${store_dir} --recursive

docker build --rm --tag ${tag} .

docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --volume ${store_dir}:/home/IaC/store \
    ${tag} \
    ${mode} $1 $2

aws s3 cp ${store_dir} s3://${s3_store} --recursive

rm -rf ${store_dir}