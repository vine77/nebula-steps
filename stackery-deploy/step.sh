#!/bin/bash
set -euo pipefail

#
# Commands
#

AWS="${AWS:-aws}"
CFN_FLIP="${CFN_FLIP:-cfn-flip}"
JQ="${JQ:-jq}"
MKDIR_P="${MKDIR_P:-mkdir -p}"
NI="${NI:-ni}"
STACKERY="${STACKERY:-stackery --non-interactive}"

#
# Variables
#

WORKDIR="${WORKDIR:-/workspace}"

#
#
#

log() {
  echo "[$( date -Iseconds )] $@"
}

err() {
  log "error: $@" >&2
  exit 2
}

usage() {
  echo "usage: $@" >&2
  exit 1
}

declare -a PACKAGES="( $( $NI get | $JQ -r 'try .os.packages // empty | @sh' ) )"
[[ ${#PACKAGES[@]} -gt 0 ]] && ( set -x ; apk --no-cache add "${PACKAGES[@]}" )

declare -a COMMANDS="( $( $NI get | $JQ -r 'try .os.commands // empty | @sh' ) )"
for COMMAND in ${COMMANDS[@]+"${COMMANDS[@]}"}; do
  ( set -x ; bash -c "${COMMAND}" )
done

STACKERY_KEY="$( $NI get -p '{ .stackery.key }' )"
[ -z "${STACKERY_KEY}" ] && usage 'spec: please specify a value for `stackery.key`, the API key to access Stackery'

STACKERY_SECRET="$( $NI get -p '{ .stackery.secret }' )"
[ -z "${STACKERY_SECRET}" ] && usage 'spec: please specify a value for `stackery.secret`, the API secret to access Stackery'

export STACKERY_KEY STACKERY_SECRET

STACKERY_EMAIL="$( $STACKERY whoami )" || {
  err 'spec: `stackery.key` and `stackery.secret` do not appear to authenticate a Stackery user'
}

log "authenticated to Stackery as ${STACKERY_EMAIL}"

STACK_NAME="$( $NI get -p '{ .stackName }' )"
[ -z "${STACK_NAME}" ] && usage 'spec: please specify `stackName`, the Stackery stack name to deploy'

ENV_NAME="$( $NI get -p '{ .environmentName }' )"
[ -z "${ENV_NAME}" ] && usage 'spec: please specify `environmentName`, the Stackery environment to deploy to'

$NI aws config -d "${WORKDIR}/.aws"
eval "$( $NI aws env -d "${WORKDIR}/.aws" )"

declare -a STACKERY_DEPLOY_ARGS

if [ -z "$( $NI get -p '{ .git.repository }' )" ]; then
  # No repository specified, so we'll run with CodeBuild.
  STACKERY_DEPLOY_ARGS+=( --strategy=codebuild )

  GIT_REF="$( $NI get -p '{ .git.branch }' )"
  if [ -z "${STACKERY_BRANCH}" ]; then
    GIT_REF=master
  fi

  STACKERY_DEPLOY_ARGS+=( "--git-ref=${GIT_REF}" )
else
  STACKERY_DEPLOY_ARGS+=( --strategy=local )

  # Get the Git repository to work from.
  $NI git clone -d "${WORKDIR}/repo" || err 'could not clone Git repository'
  [ -d "${WORKDIR}/repo" ] || usage 'spec: please specify `git`, the Git repository to use to resolve the Stackery template'

  pushd "${WORKDIR}/repo/$( $NI get -p '{ .git.name }' )" >/dev/null

  TEMPLATE_PATH="$( $NI get -p '{ .templatePath }' )"
  [ -n "${TEMPLATE_PATH}" ] && STACKERY_DEPLOY_ARGS+=( "--template-path=${TEMPLATE_PATH}" )

  TEMPLATE_RUNTIMES="$(
    $CFN_FLIP -o json "${TEMPLATE_PATH:-template.yaml}" | \
      $JQ -r '.Resources | try map(select(.Type == "AWS::Serverless::Function") | .Properties.Runtime) | unique[]'
  )"
  for TEMPLATE_RUNTIME in "${TEMPLATE_RUNTIMES}"; do
    log "installing build support for runtime ${TEMPLATE_RUNTIME}..."

    case "${TEMPLATE_RUNTIME}" in
    nodejs*)
      apk --no-cache add nodejs npm
      ;;
    python2.*)
      apk --no-cache add python2 python2-dev
      ;;
    python3.*)
      apk --no-cache add python3 python3-dev
      ;;
    ruby2.*)
      apk --no-cache add ruby ruby-dev
      ;;
    java8)
      apk --no-cache add openjdk8
      ;;
    go1.*)
      apk --no-cache add go
      ;;
    dotnetcore2.*)
      # TODO: This requires quite a bit of packaging work. See the following
      # Dockerfiles as a reference:
      #
      # https://github.com/dotnet/dotnet-docker/blob/master/3.0/runtime-deps/alpine3.10/amd64/Dockerfile
      # https://github.com/dotnet/dotnet-docker/blob/master/3.0/sdk/alpine3.10/amd64/Dockerfile
      err "unsupported runtime ${TEMPLATE_RUNTIME}"
      ;;
    *)
      err "unsupported runtime ${TEMPLATE_RUNTIME}"
      ;;
    esac
  done
fi

# Stackery doesn't understand the AWS_CONFIG_FILE / AWS_SHARED_CREDENTIALS_FILE
# environment variables, so we have to directly export the key ID and secret key
# to our environment.
export AWS_ACCESS_KEY_ID="$( $AWS configure get aws_access_key_id )"
export AWS_SECRET_ACCESS_KEY="$( $AWS configure get aws_secret_access_key )"

set -x
SAM_CLI_TELEMETRY=0 $STACKERY deploy \
  "${STACKERY_DEPLOY_ARGS[@]}" \
  --stack-name="${STACK_NAME}" \
  --env-name="${ENV_NAME}"


STACKERY_OUTPUT="$( $STACKERY describe -e $ENV_NAME -n $STACK_NAME --json )"
STACKERY_API_ID="$( $JQ '.resources.Api.restApi.id // empty' <<< "${STACKERY_OUTPUT}" )"

# If an API Gateway exists in the stack then build the URL as its provided by AWS
if [ -n "$STACKERY_API_ID" ]; then
  API_URL_STRING="$( $JQ -r '"https://\( .resources.Api.restApi.id ).execute-api.\( .region ).amazonaws.com/\( .resources.Api.stageDomainName )" // empty' <<< "${STACKERY_OUTPUT}" )"
  ni output set --key "apiURL" --value "$API_URL_STRING"
fi
