#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

function clearOld(){
set -x
    listPipeline=`aws imagebuilder list-image-pipelines`
    for row in $(echo "${listPipeline}" | jq -r '.imagePipelineList[]|select(.name|test( "[gG]olden.*[iI]mage")) | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        aws imagebuilder delete-image-pipeline --image-pipeline-arn $(_jq '.arn')
    done

    listRecipes=`aws imagebuilder list-image-recipes --owner Self`
    for row in $(echo "${listRecipes}" | jq -r '.imageRecipeSummaryList[]|select(.name|test( "[gG]olden.*[iI]mage")) | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        aws imagebuilder delete-image-recipe --image-recipe-arn $(_jq '.arn')
    done

    listComponents=`aws imagebuilder list-components --owner Self`

    for row in $(echo "${listComponents}" | jq -r '.componentVersionList[]|select(.name|test( "[gG]olden.*[iI]mage")) | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        aws imagebuilder delete-component --component-build-version-arn "$(_jq '.arn')/1"
    done
}

source environment.properties

jq --arg key0   'area' \
   --arg value0 "${AREA}" \
   --arg key1   'region' \
   --arg value1 'ap-southeast-2' \
   '. | .[$key0]=$value0 | .[$key1]=$value1' \
   <<<'{}' > IaC/01_deploy.auto.tfvars.json

ASSUME_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"

TEMP_ROLE=`aws sts assume-role --role-arn $ASSUME_ROLE_ARN --role-session-name "Deploy-pipeline"`

export AWS_ACCESS_KEY_ID=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SessionToken')

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

docker build --tag ${tag} .

clearOld

docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --volume ${store_dir}:/home/IaC/store \
    ${tag} \
    apply

aws s3 cp ${store_dir} s3://${s3_store} --recursive

rm -f IaC/01_deploy.auto.tfvars.json
rm -rf ${store_dir}