#!/bin/bash

# Exit on errors. Undefined vars count as errors.
set -eu

# Grids files
g01="${PWD}/data/grids/sample-boggle-grid.01.txt"
g02="${PWD}/data/grids/sample-boggle-grid.02.txt"
g03="${PWD}/data/grids/sample-boggle-grid.03.txt"
g04="${PWD}/data/grids/sample-boggle-grid.04.txt"
g05="${PWD}/data/grids/sample-boggle-grid.05.txt"
g06="${PWD}/data/grids/sample-boggle-grid.06.txt"
g07="${PWD}/data/grids/sample-boggle-grid.07.txt"
g08="${PWD}/data/grids/sample-boggle-grid.08.txt"

# Words files
wAme="${PWD}/data/words/american-english.boggle.words"
wInt="${PWD}/data/words/international-english.boggle.words"

# TODO: keep track of pass and fail combinations to summarize at the end
# TODO: maybe set an error code if 1 or more tests fail
# TODO: maybe use colored logging here, too? try to not compete with color scheme for boggle script
#       maybe make coloration a sourcable file, for both/all scripts
function runTestCase() {
  declare -i numArgs=${#@}
  if [ ${numArgs} -ne 3 ]; then
    echo "ERROR: function '${FUNCNAME[0]}' expectes three inputs value but received ${numArgs}"
    exit 1
  fi

  echo "Running TestCase with"
  echo "  Grid file: ${1}"
  echo "  Word file: ${2}"
  echo "  Expected Hash: ${3}"
  ./boggle.find-words.sh -g "${1}" -w "${2}" --no-info --no-debug --test "${3}"
  echo
}

runTestCase "${g01}" "${wAme}" "b548c0cf048b62085dfc43e61ac834d7"
runTestCase "${g02}" "${wAme}" "ee364f10c59f96daa31f92f24d6dbac3"
runTestCase "${g03}" "${wAme}" "9eb8f0475cabd451f580624a8efde712"
runTestCase "${g04}" "${wAme}" "aeea885450daf2ab8ed86b940e677a17"
runTestCase "${g05}" "${wAme}" "13f87371102d28420ddddd6b65a10c60"
runTestCase "${g06}" "${wAme}" "bcf6d94ed05c45d9d6e347cfa6b60217"
runTestCase "${g07}" "${wAme}" "600aa2de6a29cddcb9f917eb1a040470"
runTestCase "${g08}" "${wAme}" "2f509e09dd5e225e850daf9b8f1ee094"

runTestCase "${g01}" "${wInt}" "90c8d7790a053eef64f5b265a7133314"
runTestCase "${g02}" "${wInt}" "d497e30fdda2c2467d42b8f0e27793ae"
runTestCase "${g03}" "${wInt}" "1cbf70e3b6a5f8939579aef9ac2445ef"
runTestCase "${g04}" "${wInt}" "3d0417729a5722b2a41a2f0caf007fea"
runTestCase "${g05}" "${wInt}" "eb6ee643d6a45bf37842df016ab87a28"
runTestCase "${g06}" "${wInt}" "1f136abfcaf5989830948b770cd0513f"
runTestCase "${g07}" "${wInt}" "0fd99ac00290de9c17d754f8b9cd070f"
runTestCase "${g08}" "${wInt}" "856e813ad98058a8fdb23fe8028bc653"
