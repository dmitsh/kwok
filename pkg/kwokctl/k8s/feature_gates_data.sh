#!/usr/bin/env bash
# Copyright 2022 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# https://github.com/kubernetes/website/blob/main/content/en/docs/reference/command-line-tools-reference/feature-gates.md
# Some details of the feature gate on the official website are not synchronized so here we use a script to get the real details in the code

set -o errexit
set -o nounset
set -o pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"

latest_release="${1:-}"

# Kubernetes added Feature Gate in 1.6
minimum_release=6

if [[ ! "${latest_release}" -gt "${minimum_release}" ]]; then
  echo "Must be greater than ${minimum_release}"
  exit 1
fi

function features() {
  file_paths=(
    "pkg/features/kube_features.go"
    "staging/src/k8s.io/component-base/metrics/features/kube_features.go"
    "staging/src/k8s.io/component-base/logs/api/v1/kube_features.go"
    "staging/src/k8s.io/controller-manager/pkg/features/kube_features.go"
    "staging/src/k8s.io/apiextensions-apiserver/pkg/features/kube_features.go"
    "staging/src/k8s.io/apiserver/pkg/features/kube_features.go"
  )
  for i in $(seq "${minimum_release}" "${latest_release}"); do
    for p in "${file_paths[@]}"; do
      curl -sSL "https://github.com/kubernetes/kubernetes/raw/release-1.${i}/${p}" |
        grep "{Default: " |
        sed -e 's/\w\+\.//g' |
        sed -e 's/[:,}]//g' |
        awk "{print \$1, \$5, $i}"
    done
  done
}

function gen() {
  cat <<EOF
/*
Copyright 2022 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package k8s

// Don't edit this file directly.  It is generated by feature_gates_data.sh.
EOF

  echo "var rawData = []FeatureSpec{"
  raw="$(features | sort)"

  raw="${raw//ExperimentalHostUserNamespaceDefaultingGate/ExperimentalHostUserNamespaceDefaulting}"

  gates="$(echo "${raw}" | awk '{print $1}' | sort -u)"

  for gate in ${gates}; do
    stage="$(echo "${raw}" | grep -e "^${gate} " | awk '{print $2}' | sort -u)"
    since_release=""
    until_release=""

    echo
    echo "	// ${gate}"
    for s in ${stage}; do
      release="$(echo "${raw}" | grep -e "^${gate} ${s} " | awk '{print $3}' | sort -n)"
      since_release="$(echo "${release}" | head -n 1)"
      until_release="$(echo "${release}" | tail -n 1)"
      if [[ "${until_release}" == "${latest_release}" ]]; then
        until_release="-1"
      fi
      echo "	{\"${gate}\", ${s}, ${since_release}, ${until_release}},"
    done
  done
  echo "}"
}

function gen_file() {
  gen >"${DIR}/feature_gates_data.go"
}

gen_file
