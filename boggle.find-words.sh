#!/bin/bash

# File on errors. Undefined vars count as errors.
set -eu

# Declare some files for later selection
GRID_01="/home/cory/git/boggle/data/grids/sample-boggle-grid.01.txt2"
GRID_03="/home/cory/git/boggle/data/grids/sample-boggle-grid.03.txt"
GRID_02="/home/cory/git/boggle/data/grids/sample-boggle-grid.02.txt"

AMERICAN_ENGLISH_WORDS="/home/cory/git/boggle/data/words/american-english.words"
SCRABBLE_BOGGLE_WORDS="/home/cory/git/boggle/data/words/scrabble.boggle.words"
SCRABBLE_ALL_WORDS="/home/cory/git/boggle/data/words/scrabble.all.words"

BOGGLE_DICE_TXT="/home/cory/git/boggle/data/dice/boggle-dice.txt"

# Exit codes (to be OR'd together ('|'))
declare -i FILE_MISSING=1
declare -i FILE_UNREADABLE=2

# Select specific files to use this run
GRID="${GRID_01}"
WORDS="${AMERICAN_ENGLISH_WORDS}"

# Verify chosen files exist
declare -i exitCode=0
if [ ! -f "${GRID}" ]; then
  echo "ERROR: Boggle grid file '${GRID}' does not exist"
  exitCode=$((exitCode | FILE_MISSING))
elif [ ! -r "${GRID}" ]; then
  echo "ERROR: Boggle grid file '${GRID}' exists but it cannot be read"
  exitCode=$((exitCode | FILE_UNREADABLE))
fi

if [ ! -f "${WORDS}" ]; then
  echo "ERROR: Boggle words file '${WORDS}' does not exist"
  exitCode=$((exitCode | FILE_MISSING))
elif [ ! -r "${WORDS}" ]; then
  echo "ERROR: Boggle words file '${WORDS}' exists but it cannot be read"
  exitCode=$((exitCode | FILE_UNREADABLE))
fi

if [ ${exitCode} -gt 0 ]; then
  echo
  echo "An error was encountered. Exiting early with exit code ${exitCode}"
  exit ${exitCode}
else
  echo "PASS !!!!"
fi
