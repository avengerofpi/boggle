#!/bin/bash

# Exit on errors. Undefined vars count as errors.
#set -eu

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
  echo "  Expected filtered file: ${3}"
  ./boggle.find-words.sh -g "${1}" -w "${2}" --no-info --no-debug --test "${3}"
  echo
}

for wType in "american" "international"; do
  for gi in {01..08}; do
    g="${PWD}/data/grids/sample-boggle-grid.${gi}.txt"
    w="${PWD}/data/words/${wType}-english.boggle.words"
    t="${PWD}/data/test/words.sample-boggle-grid.${gi}.txt---${wType}-english.boggle.words---filtered.txt"
    runTestCase "${g}" "${w}" "${t}"
  done
done
