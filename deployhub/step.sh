#!/bin/bash

set -euo pipefail

#
# Commands
#

JQ="${JQ:-jq}"
NI="${NI:-ni}"

#
#
#
usage() {
  echo "usage: $@" >&2
  exit 1
}

#
# Variables
#

WORKDIR="${WORKDIR:-/workspace}"


declare -a DH_ARGS

ACTION="$( $NI get -p '{ .action }' )"
[ -z "${ACTION}" ] && usage 'spec: please specify a value for `.action`, the name of the action to perform'
[ -n "${ACTION}" ] && DH_ARGS+=( "${ACTION}" )

DHURL="$( $NI get -p '{ .registry.url }' )"
[ -z "${DHURL}" ] && usage 'spec: please specify a value for `.registry.url`, the DeployHub Server URL'
[ -n "${DHURL}" ] && DH_ARGS+=( "--dhurl" ) && DH_ARGS+=( "${DHURL}" )

DHUSER="$( $NI get -p '{ .registry.username }' )"
[ -z "${DHUSER}" ] && usage 'spec: please specify a value for `.registry.username`, the DeployHub User Id'
[ -n "${DHUSER}" ] && DH_ARGS+=( "--dhuser" )  && DH_ARGS+=( "${DHUSER}" )

DHPASS="$( $NI get -p '{ .registry.password }' )"
[ -z "${DHPASS}" ] && usage 'spec: please specify a value for `.registry.password`, the DeployHub Password'
[ -n "${DHPASS}" ] && DH_ARGS+=( "--dhpass" ) && DH_ARGS+=( "${DHPASS}" )

APPNAME="$( $NI get -p '{ .appname }' )"
[ -z "${APPNAME}" ] && usage 'spec: please specify a value for `.appname`, the Application Name'
[ -n "${APPNAME}" ] && DH_ARGS+=( "--appname" ) && DH_ARGS+=( "${APPNAME}" )

APPVERSION="$( $NI get -p '{ .appversion }' )"
[ -n "${APPVERSION}" ] && DH_ARGS+=( "--appversion" ) && DH_ARGS+=( "${APPVERSION}" )

DEPLOYENV="$( $NI get -p '{ .deployenv }' )"
[ -n "${DEPLOYENV}" ] && DH_ARGS+=( "--deployenv" ) && DH_ARGS+=( "${DEPLOYENV}" )

COMPNAME="$( $NI get -p '{ .compname }' )"
[ -n "${COMPNAME}" ] && DH_ARGS+=( "--compname" ) && DH_ARGS+=( "${COMPNAME}" )

COMPVARIANT="$( $NI get -p '{ .compvariant }' )"
[ -n "${COMPVARIANT}" ] && DH_ARGS+=( "--compvariant" ) && DH_ARGS+=( "${COMPVARIANT}" )

COMPVERSION="$( $NI get -p '{ .compversion }' )"
[ -n "${COMPVERSION}" ] && DH_ARGS+=( "--compversion" ) && DH_ARGS+=( "${COMPVERSION}" )

KIND="$( $NI get -p '{ .docker }' )"
[ -n "${KIND}" ] && DH_ARGS+=( "--docker" )

KIND="$( $NI get -p '{ .file }' )"
[ -n "${KIND}" ] && DH_ARGS+=( "--file" )

COMPATTR="$( $NI get -p '{ .compattr }' )"
[ -n "${COMPATTR}" ] && DH_ARGS+=( "--compattr" ) && DH_ARGS+=( "${COMPATTR}" )

ENVS="$( $NI get -p '{ .envs }' )"
[ -n "${ENVS}" ] && DH_ARGS+=( "--envs" ) && DH_ARGS+=( "${ENVS}" )

dh "${DH_ARGS[@]}"

ni log info "DeployHub ${ACTION} completed"
