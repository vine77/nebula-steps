#!/usr/bin/env bash

OS="${OSTYPE//[0-9.-]*/}"

DOCKER="${DOCKER:-docker}"
GO="${GO:-go}"

if [ "$OS" == "darwin" ]; then
  DIRNAME="${DIRNAME:-gdirname}"
  READLINK_F="${READLINK_F:-greadlink -f}"
  XARGS_R="${XARGS:-gxargs -r}"
else
  DIRNAME="${DIRNAME:-dirname}"
  READLINK_F="${READLINK_F:-readlink -f}"
  XARGS_R="${XARGS:-xargs -r}"
fi



#
#
#

nebula::steps::step_files() {
  local RELFILE ABSFILE

  while IFS= read RELFILE; do
    ABSFILE="$( cd hack/generate && $READLINK_F "${RELFILE}" )"
    [ -z "${ABSFILE}" ] && continue

    printf "%s\n" "${ABSFILE##$( pwd )/}"
  done < <( cd hack/generate && $GO run github.com/puppetlabs/nebula-sdk/cmd/spindle list -rq ../.. )
}

nebula::steps::step_dirs() {
  nebula::steps::step_files | $XARGS_R $DIRNAME
}

nebula::steps::step_images() {
  $DOCKER image ls \
    --filter=label=com.puppet.nebula.sdk.version \
    --filter=reference='projectnebula/*' \
    --format='{{ .Repository }}:{{ .Tag }}'
}

nebula::steps::usage() {
  echo "usage: $*" >&2
  exit 1
}
