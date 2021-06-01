#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

. ./init.sh

source environment.properties

mode="shell"
# mode="destroy"
tag="dta-iac/goldern-image"

store_dir=$(mktemp -d -t tf_XXXXXXXXXX)

s3_bucket=`echo "${DEPARTMENT}-${AREA}-v4"|tr "[:upper:]" "[:lower:]"`
LIST_BUCKETS=`aws s3api list-buckets`

CreationDate=`jq ".Buckets[]|select(.Name==\"${s3_bucket}\").CreationDate" <<< "$LIST_BUCKETS"`
if [[ -z "${CreationDate}" ]]; then

    aws s3api create-bucket --bucket ${s3_bucket} --acl private --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION}
    aws s3api put-public-access-block --bucket ${s3_bucket} \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    aws s3api put-bucket-versioning --bucket ${s3_bucket} \
         --versioning-configuration Status=Enabled
fi

s3_store="${s3_bucket}/${tag}/store"

aws s3 cp s3://${s3_store} ${store_dir} --recursive

docker build --rm --tag ${tag} .

docker run \
    --tty --interactive \
    --rm \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --volume ${store_dir}:/home/IaC/store \
    ${tag} \
    ${mode}


rm -rf ${store_dir}