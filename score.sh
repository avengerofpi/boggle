#!/bin/bash

function logInfo() { return; }
function logScore() { echo "${@}"; }

function scoreWordsFile() {
  local wordsFile="${1}"
  logInfo "Scoring words file '${wordsFile}'"
  declare -A scoringMap=(
    [4]=1
    [5]=2
    [6]=3
    [7]=5
    [8,]=11
  )
  declare -i valuePerWord numWords inc score
  for wordLengthToGrepFor in $(for k in "${!scoringMap[@]}"; do echo "${k}"; done | sort -n); do
    valuePerWord="${scoringMap[${wordLengthToGrepFor}]}"
    numWords=$(egrep "^.{${wordLengthToGrepFor}}$" "${wordsFile}" | wc -l)
    inc=$((valuePerWord * numWords))
    local formatStr="  %3d words of length %-2s -> %2d points/word -> %4d more points"
    local outStr="$(printf "${formatStr}" ${numWords} ${wordLengthToGrepFor} ${valuePerWord} ${inc})"
    logInfo "${outStr}"
    score+=${inc}
  done
  scoreString="$(printf "%4d points total" "${score}")"
  logInfo
  logInfo "  ${scoreString}"
  logScore "  $(basename "${scoreString}")"
  #logScore "  ${scoreString} (${filteredWordsFile})"
}

export scoreWordsFile logInfo logScore
