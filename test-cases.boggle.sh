#!/bin/bash

# Exit on errors. Undefined vars count as errors.
set -eu

# Select an output dir to use
declare -i outputDirIndex=""
declare outputDir=""
function setupOutputDir() {
  baseOutputDir="${PWD}/data/test/results"
  outputDirFormatStr="${baseOutputDir}/%05d"
  outputDir=""
  for outputDirIndex in {0..99999}; do
    putative_outputDir="$(printf "${outputDirFormatStr}" "${outputDirIndex}")"
    if [ ! -e "${putative_outputDir}" ]; then
      outputDir="${putative_outputDir}"
      break;
    fi;
  done;

  if [ -z "${outputDir}" ]; then
    logError "Failed to choose a usable output dir."
    exit 1
  fi

  mkdir -p "${outputDir}"
  echo "Output dir: ${outputDir}"
}

# Grids files
GRID_FILE_FORMAT_STR="${PWD}/data/grids/sample-boggle-grid.%s.txt"
GRID_FILE_LABELS=({01..09})
# Depends on: gridFileLabel
function setGridFile() {
  gridFile="$(printf "${GRID_FILE_FORMAT_STR}" "${gridFileLabel}")"
}

# Words files
WORDS_FILE_FORMAT_STR="${PWD}/data/words/%s.boggle.words"
WORDS_FILE_LABELS=(
  "american-english"
  "international-english"
)
# Depends on: wordFileLabel
function setWordFile() {
  wordFile="$(printf "${WORDS_FILE_FORMAT_STR}" "${wordFileLabel}")"
}

# Expect filtered word lists
EXPECTED_WORDS_FILE_FORMAT_STR="${PWD}/data/test/expected-words/expected-words.%s.grid-%s.txt"
# Depends on: wordFileLabel gridFileLabel
function setTestFile() {
  testFile="$(printf "${EXPECTED_WORDS_FILE_FORMAT_STR}" "${wordFileLabel}" "${gridFileLabel}")"
}

# Expect filtered word lists
# Depends on: wordFileLabel gridFileLabel
function setOutputFile() {
  OUTPUT_FILE_FORMAT_STR="${outputDir}/%s.grid-%s.txt"
  outputFile="$(printf "${OUTPUT_FILE_FORMAT_STR}" "${wordFileLabel}" "${gridFileLabel}")"
  outputFiles+=("${outputFile}")
}

# TODO: maybe use colored logging here, too? try to not compete with color scheme for boggle script
# Depends on: wordFileLabel gridFileLabel
function runTestCase() {
  setGridFile
  setWordFile
  setTestFile
  setOutputFile

  echo "Running TestCase with"
  echo "    Grid file: ${gridFile}"
  echo "    Word file: ${wordFile}"
  echo "    Test file: ${testFile}"
  echo "  Output file: ${outputFile}"

  colorFlag="--no-color"
  debugFlag="--no-debug"
  infoFlag="--info"
  warnFlag="--warn"
  errorFlag="--error"
  scoreFlag="--score"
  loggingFlags="${colorFlag} ${debugFlag} ${infoFlag} ${warnFlag} ${errorFlag} ${scoreFlag}"

  set +e
  nohup /usr/bin/time -pao "${outputFile}" ./boggle.find-words.sh -g "${gridFile}" -w "${wordFile}" -t "${testFile}" ${loggingFlags} > "${outputFile}" &
  set -eu
  echo
}

# Check output files and summarize results
outputFiles=()
summarizeResults() {
  failPattern="Test FAILURE"
  passPattern="Test SUCCESS"
  declare -i numFiles=$(ls -1                   "${outputFiles[@]}" | wc -l)
  declare -i numPass=$(grep -l "${passPattern}" "${outputFiles[@]}" | wc -l)
  declare -i numFail=$(grep -l "${failPattern}" "${outputFiles[@]}" | wc -l)

  declare -i numGridFiles=${#GRID_FILE_LABELS[@]}
  declare -i numWordFiles=${#WORDS_FILE_LABELS[@]}
  declare -i expectedNumFiles=${#outputFiles[@]}

  # Make sure we have the expected number of outpuf files
  if [ ${numFiles} -ne ${expectedNumFiles} ]; then
    echo "Error: there are ${numFiles} output files but we expected to find ${expectedNumFiles}"
    exit 2
  fi

  echo "Waiting for all tests to pass..."
  declare -i totalDone=$((numPass + numFail))
  declare -i sleepSeconds=10
  while [ ${numFiles} -ne ${totalDone} ]; do
    printf "  Not done yet - %2d of %2d tests finished - sleeping another %d seconds\n" ${totalDone} ${expectedNumFiles} ${sleepSeconds}
    sleep ${sleepSeconds}
    numPass=$(grep -l "${passPattern}" "${outputFiles[@]}" | wc -l)
    numFail=$(grep -l "${failPattern}" "${outputFiles[@]}" | wc -l)
    totalDone=$((numPass + numFail))
  done
  echo
  printf "%2d test report files\n"  ${numFiles}
  printf "%2d tests passed\n"       ${numPass}
  printf "%2d tests failed\n"       ${numFail}
}

declare wordFileLabel gridFileLabel
declare -a outputFiles=()
function runTestCases() {
  for wordFileLabel in "${WORDS_FILE_LABELS[@]}"; do
    for gridFileLabel in "${GRID_FILE_LABELS[@]}"; do
      runTestCase "${gridFileLabel}" "${wordFileLabel}"
    done
  done
}

main() {
  setupOutputDir
  runTestCases
  summarizeResults
}

main
