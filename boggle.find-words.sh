#!/bin/bash

# Exit on errors. Undefined vars count as errors.
set -eu

# TODO: Some of the slowness might be b/c I have a lot of logging of strings
# that get expanded regardless of whether their respective log level is turned
# on, and some of these strings are long.

# Default ogging levels
   debug=false;
    info=true;
    warn=true;
   error=true;
scoreLog=true;

# To turn colored output off and on, and to enable command-line flags so this
# can be chosen at runtime use function var 'myTput' to choose between real
# tput-based coloring and uncolored output (use whatever coloring the terminal
# is already set to).
# TODO: clarify in my comments that tput is being used for slightly more than just coloring
function noColorTput() {
  return
}
function turnColorOn() {
  logDebug "Turning color ON"
  # Use a function instead of an alias so that it will stick
  unset -f myTput
  function myTput() {
    tput "${@}"
  }
  setupColoring
}
function turnColorOff() {
  logDebug "Turning color OFF"
  # Use a function instead of an alias so that it will stick
  unset -f myTput
  function myTput() {
    return
  }
  setupColoring
}

# Argument parsing
# Based on suggestions from https://drewstokes.com/bash-argument-parsing
declare randomFiles=false
declare testing=false
declare GRID="" WORDS=""
declare EXPECTED_TEST_FILE=""
function parseArgs() {
  while (( "$#" )); do
    case "$1" in
      # Flags for explicit file choices
      -g|--grid-file)
        if [ -n "${2:-}" ] && [ ${2:0:1} != "-" ]; then
          GRID="$2"
          logDebug "Choosing GRID file '${GRID}'"
          shift 2
        else
          logError "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -w|--words-file)
        if [ -n "${2:-}" ] && [ ${2:0:1} != "-" ]; then
          WORDS="$2"
          logDebug "Choosing WORDS file '${WORDS}'"
          shift 2
        else
          logError "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      # Turn on random selection/generation for any files not explicity chosen
      -r|--random-files)
        randomFiles=true
        logDebug "Choosing random files instead of prompting user (unless file was chosen by another argument)"
        shift 1
        ;;
      # Testing option. User passes in the name of a files contained the expected final words list to compare against.
      # Requires the user to manually set grid and words files. (How else would the user know what to expect?)
      -t|--test)
        testing=true
        if [ -n "${2:-}" ] && [ ${2:0:1} != "-" ]; then
          EXPECTED_TEST_FILE="$2"
          logDebug "Turning on testing option. EXPECTED_TEST_FILE: '${EXPECTED_TEST_FILE}'"
          shift 2
        else
          logError "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      # Color toggling. Won't affecting logging that already happened
      --color)
        turnColorOn
        shift 1
        ;;
      --no-color)
        turnColorOff
        shift 1
        ;;
      # Turn logging options on
      --debug)
        debug=true
        shift 1
        ;;
      --info)
        info=true
        shift 1
        ;;
      --warn)
        warn=true
        shift 1
        ;;
      --error)
        error=true
        shift 1
        ;;
      --score)
        scoreLog=true
        shift 1
        ;;
      # Turn logging options off
      --no-debug)
        debug=false
        shift 1
        ;;
      --no-info)
        info=false
        shift 1
        ;;
      --no-warn)
        warn=false
        shift 1
        ;;
      --no-error)
        error=false
        shift 1
        ;;
      --no-score)
        scoreLog=false
        shift 1
        ;;
      # Unsupported and positional args
      -*|--*=) # unsupported flags
        logError "Error: Unsupported flag $1" >&2
        exit 1
        ;;
      *) # positional parameters - unsupported
        logError "Encountered a positional param, but no positional params are supported"
        exit 2
        ;;
    esac
  done

  validateParsedArgs
}

function validateParsedArgs() {
  # If testing option was set, ensure files were also set
  logDebug "Validating parsed args"
  if ${testing}; then
    logDebug "  testing option was set."
    if ${randomFiles}; then
      logError "Validating parsed args"
      logError "  testing option was set."
      logError "    randomFiles option was set, but this is incompatible with testing"
      exitCode=$((exitCode | TESTING_SETUP_ERROR))
    fi
    if [ -z "${GRID}" ]; then
      logError "Validating parsed args"
      logError "  testing option was set."
      logError "    GRID file needs to be manually set on command-line to enable testing"
      exitCode=$((exitCode | TESTING_SETUP_ERROR))
    fi
    if [ -z "${WORDS}" ]; then
      logError "Validating parsed args"
      logError "  testing option was set."
      logError "    WORDS file needs to be manually set on command-line to enable testing"
      exitCode=$((exitCode | TESTING_SETUP_ERROR))
    fi
    # Check testing file
    if [ ! -f "${EXPECTED_TEST_FILE}" ]; then
      logError "Validating parsed args"
      logError "  testing option was set."
      logError "    Testing expected filtered words file '${EXPECTED_TEST_FILE}' does not exist"
      exitCode=$((exitCode | FILE_MISSING))
    elif [ ! -r "${EXPECTED_TEST_FILE}" ]; then
      logError "Validating parsed args"
      logError "  testing option was set."
      logError "    Testing expected filtered words file '${EXPECTED_TEST_FILE}' exists but it cannot be read"
      exitCode=$((exitCode | FILE_UNREADABLE))
    fi
    checkExitCode
  fi
}

# Select an output dir to use
declare -i outputDirIndex=""
declare outputDir=""
function setupOutputDir() {
  datetime="$(date +"%F-%Hh%Mm%Ss")"
  baseOutputDir="${PWD}/output"
  outputDirFormatStr="${baseOutputDir}/%05d"
  outputDir=""
  for outputDirIndex in {0..99999}; do
    putative_outputDir="$(printf "${outputDirFormatStr}" "${outputDirIndex}")"
    logDebug "Checking whether (putative) output dir '${putative_outputDir}' exists already"
    if [ ! -e "${putative_outputDir}" ]; then
      logDebug "  Does not exist yet. We will use '${putative_outputDir}' as the output dir"
      outputDir="${putative_outputDir}"
      break;
    fi;
  done;

  if [ -z "${outputDir}" ]; then
    logError "Failed to choose a usable output dir."
    exitCode=$((exitCode | 99))
  fi
  checkExitCode

  mkdir -p "${outputDir}"
  touch "${outputDir}/${datetime}.txt"
}

# Coloration
# TODO: maybe make coloration a sourcable file, for both/all scripts
function setupColoring() {
TPUT_RESET="$(myTput sgr0)";

 FAINT="$(myTput dim)";
BRIGHT="$(myTput bold)";

   RED_FG="$(myTput setaf  1)";
 GREEN_FG="$(myTput setaf  2)";
YELLOW_FG="$(myTput setaf 11)";
  CYAN_FG="$(myTput setaf 14)";
PURPLE_FG="$(myTput setaf 93)";

BRIGHT_RED_FG="${BRIGHT}${RED_FG}";
FAINT_GREEN_FG="${FAINT}${GREEN_FG}";
BRIGHT_YELLOW_FG="${BRIGHT}${YELLOW_FG}";
BRIGHT_CYAN_FG="${BRIGHT}${CYAN_FG}";
BRIGHT_PURPLE_FG="${BRIGHT}${PURPLE_FG}";

   RED_BG="$(myTput setab 9)";
 GREEN_BG="$(myTput setab 2)";
YELLOW_BG="$(myTput setab 3)";

   DEBUG_COLOR="${BRIGHT_CYAN_FG}";
    INFO_COLOR="${BRIGHT_YELLOW_FG}";
    WARN_COLOR="${BRIGHT_PURPLE_FG}";
   ERROR_COLOR="${BRIGHT_RED_FG}";
   SCORE_COLOR="${YELLOW_BG}${BRIGHT_RED_FG}";
 TESTING_COLOR="${GREEN_BG}${BRIGHT_YELLOW_FG}";

  logDebug "Coloring is now setup"
  setupLoggingFunctions
}

# Logging functions
function setupLoggingFunctions() {
unset -f logDebug logInfo logWarn logError logScore logTesting
function logDebug()    { if $debug;     then echo -e   "${DEBUG_COLOR:-}DEBUG:" "${@}${TPUT_RESET:-}"; fi; }
function logInfo()     { if $info;      then echo -e    "${INFO_COLOR:-}INFO: " "${@}${TPUT_RESET:-}"; fi; }
function logWarn()     { if $warn;      then echo -e    "${WARN_COLOR:-}WARN: " "${@}${TPUT_RESET:-}"; fi; }
function logError()    { if $error;     then echo -e   "${ERROR_COLOR:-}ERROR:" "${@}${TPUT_RESET:-}"; fi; }
function logScore()    { if $scoreLog;  then echo -e   "${SCORE_COLOR:-}SCORE:" "${@}${TPUT_RESET:-}"; fi; }
function logTesting()  {                     echo -e "${TESTING_COLOR:-}TEST: " "${@}${TPUT_RESET:-}";     }

logDebug "Logging is now setup"
}

# Declare files/file lists for later usage
function selectDefaultFileOptionLists() {
  # TODO: make vars for these dirs
  # TODO: mv ./data/{grids,words,dice} to just ./{grids,words,dice}
  GRID_FILES=(
    ${PWD}/data/grids/*.txt
  )

  WORD_FILES=(
    ${PWD}/data/words/*.words
  )

  BOGGLE_DICE_TXT="${PWD}/data/dice/sample-boggle-dice.txt"
}

# Generate a random boggle board from the selected dice config file
function generateRandomGrid() {
  declare -a shuffledDice
  readarray -t shuffledDice < <(shuf ${BOGGLE_DICE_TXT})
  logDebug "Generating a new, random grid file"
  logDebug "  Using dice file '${BOGGLE_DICE_TXT}'"
  logDebug "Shuffled dice:"
  for die in "${shuffledDice[@]}"; do
    logDebug "  ${die}";
  done

  # TODO: make the numbering of outputDir and grid filename more tightly coupled
  randomGridFilenameBasename="random-boggle-grid.%05d.txt"
  randomGridFilenameFormatStr="${outputDir}/${randomGridFilenameBasename}"
  GRID="$(printf "${randomGridFilenameFormatStr}" "${outputDirIndex}")"
  touch "${GRID}"
  declare -i rowNum colNum idx
  for rowNum in {0..4}; do
    line=""
    for colNum in {0..4}; do
      idx=$((5*rowNum + colNum))
      die="${shuffledDice[${idx}]}"
      clue="$(echo "${die}" | sed -e 's@ @\n@g' | shuf | head -1)"
      logDebug "Rolled die '${die}' and selected face '${clue}'"
      # Line the clues up (assuming max clue length remains 2 chars)
      line+="$(printf "%2s " "${clue}")"
    done
    line="${line% }"
    logDebug "Appending line '${line}' to grid file"
    echo "${line}" >> "${GRID}"
  done
  logInfo "Random grid file generated:"
  logInfo "\n$(cat "${GRID}")"
  cp "${GRID}" "${PWD}/data/grids/random/"
}

# Prompt user to select specific files to use this run unless a file was
# already specified on command-line or random selection was specified
function promptUserForGridAndWordFiles() {
  GRID_PROMPT="Choose the grid file to use: "
  WORDS_PROMPT="Choose the words file to use: "
  # Select grid file
  createGridCopy=true
  if [ -z "${GRID}" ]; then
    if ${randomFiles}; then
      generateRandomGrid
      createGridCopy=false
    else
      PS3="${GRID_PROMPT}"
      select GRID in "${GRID_FILES[@]}"; do
        if [ -n "${GRID}" ]; then
          break
        else
          echo "Try again. Focus!"
        fi
      done
    fi
  fi
  if ${createGridCopy}; then
    cp "${GRID}" "${outputDir}"
  fi

  # Select words file
  if [ -z "${WORDS}" ]; then
    if ${randomFiles}; then
      WORDS="$(for f in "${WORD_FILES[@]}"; do echo "${f}"; done | shuf | head -1)"
    else
      PS3="${WORDS_PROMPT}"
      select WORDS in "${WORD_FILES[@]}"; do
        if [ -n "${WORDS}" ]; then
          break
        else
          echo "Try again. Focus!"
        fi
      done
    fi
  fi
  logInfo "Selected grid  file '${GRID}'"
  logInfo "Selected words file '${WORDS}'"
}

# Exit codes and handling (to be OR'd together ('|'))
declare -i FILE_MISSING=1
declare -i FILE_UNREADABLE=2
declare -i INVALID_GRID_FILE=4
declare -i GREP_ERROR=8
declare -i TESTING_SETUP_ERROR=16
declare -i TESTING_FAILED_ERROR=32

# Exit if exitCode has been set, log and exit if so
# TODO: improve exitCode values...there's more of them now and I'm not being
#       consistent, and it might not be feasible to maintain the bit-level
#       based logical-OR operation superposition of exitCodes I originally
#       wanted to maintain.
declare -i exitCode=0
function checkExitCode() {
  if [ ${exitCode} -gt 0 ]; then
    logError
    logError "An error was encountered. Exiting early with exit code ${exitCode}"
    exit ${exitCode}
  fi
}

# Functions to perform checks/validations before rest of code runs

# Verify chosen files exist
function validateFiles() {
  if [ ! -f "${GRID}" ]; then
    logError "ERROR: Boggle grid file '${GRID}' does not exist"
    exitCode=$((exitCode | FILE_MISSING))
  elif [ ! -r "${GRID}" ]; then
    logError "ERROR: Boggle grid file '${GRID}' exists but it cannot be read"
    exitCode=$((exitCode | FILE_UNREADABLE))
  fi

  if [ ! -f "${WORDS}" ]; then
    logError "ERROR: Boggle words file '${WORDS}' does not exist"
    exitCode=$((exitCode | FILE_MISSING))
  elif [ ! -r "${WORDS}" ]; then
    logError "ERROR: Boggle words file '${WORDS}' exists but it cannot be read"
    exitCode=$((exitCode | FILE_UNREADABLE))
  fi
  checkExitCode

  # Validate number of lines in grid files
  declare -i EXPECTED_NUM_LINES=5
  declare -i numLines=$(wc "${GRID}" | awk '{print $1}')
  if [ ${numLines} -ne ${EXPECTED_NUM_LINES} ]; then
    logError "Incorrect number of lines found in grid file."
    logError "  Found '${numLines}' lines but should have found '${EXPECTED_NUM_LINES}' lines"
    exitCode=$((exitCode | INVALID_GRID_FILE))
  fi

  # Verify each line looks correct (eactly 5 non-empty alphabetical clues)
  gridLinePattern="^ *[a-z]+( +[a-z]+){4}\$"
  # Avoid grep error
  set +e
  gridAntiMatch="$(egrep -nv "${gridLinePattern}" "${GRID}")"
  if [ $? -eq 2 ]; then
    logError "There was an error with the grep command just run"
    exitCode=$((exitCode | GREP_ERROR))
  fi
  set -e
  if [ -n "${gridAntiMatch}" ]; then
    logError "One or more lines of the grid file looks incorrect."
    logError "  All lines should match the regex '${gridLinePattern}' but we found the following lines (maybe truncated):"
    logError "\n$(echo "${gridAntiMatch}" | head)"
    exitCode=$((exitCode | INVALID_GRID_FILE))
  fi
  checkExitCode
}

# Start fast filtering of words file using regex patterns built from the
# current grid file

function logFilteredHitCount() {
  numHits=$(wc -l "${filteredWordsFile}" | awk '{print $1}')
  logInfo "Number of filtered hits found: '${numHits}'"
}

# Create writable copy of selected words file.
# We will filter on this copy rather than on the original.
declare extension="txt"
declare filteredWordsFile=""
declare filteredWordsFile2=""
declare filteredWordsFile3=""
declare filteredWordsFile4=""
declare filteredWordsFileSortedByLength=""
function createInitialFilteredWordsFile() {
  gridBasename="$(basename "${GRID}")"
  wordsBasename="$(basename "${WORDS}")"
  filteredWordsFilePrefix="${outputDir}/words.${gridBasename}---${wordsBasename}---filtered"
  filteredWordsFile="${filteredWordsFilePrefix}.${extension}"
  filteredWordsFile2="${filteredWordsFilePrefix}.2.${extension}"
  filteredWordsFile3="${filteredWordsFilePrefix}.3.${extension}"
  filteredWordsFile4="${filteredWordsFilePrefix}.4.${extension}"
  filteredWordsFileSortedByLength="${filteredWordsFilePrefix}.sorted-by-length.${extension}"
  filteredWordsFileOrig="${filteredWordsFile}.orig"
  logInfo "Saving filtered words to file: ${filteredWordsFile}"
  cp "${WORDS}" "${outputDir}"
  cp "${WORDS}" "${filteredWordsFile}"
  chmod u+w "${filteredWordsFile}"
  logFilteredHitCount
}

# Add a pattern to filter out hits with too many of any char (or multi-char)

# Get counts of each char used over all clues and ensure no word exceeds the
# max for each char. This includes filtering out words that contain any char
# not included in any clue.
function performCharCountsFiltering() {
  declare -A charCnts
  for c in {a..z}; do
    charCnts["${c}"]="0";
  done
  # In order to udpate the arrays from within the while loop, use process
  # substitution instead of a pipeline
  # https://stackoverflow.com/questions/9985076/bash-populate-an-array-in-loop
  #   "Every command in a pipeline receives a copy of the shell's execution
  #     environment, so a while loop would populate a copy of the array, and when
  #     the while loop completes, that copy disappears"
  # charCnts:
  while read cnt char; do
    logDebug "Found clue '${char}' (cnt: '${cnt}')"
    charCnts["${char}"]="${cnt}"
  done < <(sed -e 's@\(.\)@\n\1@g' "${GRID}" | grep '[a-z]' | sort | uniq -c)

  logDebug
  logDebug "chars:  '${!charCnts[@]}'"
  logDebug "counts: '${charCnts[@]}'"

  # Now process each clue.
  for char in "${!charCnts[@]}"; do
    logDebug "Checking for too many hits against char '${char}'"
    declare -i maxHits="${charCnts["${char}"]}"
    declare -i excessiveHits=${maxHits}+1
    checkPattern="^\(.*${char}\)\{${excessiveHits},\}"
    logDebug "checkPattern: '${checkPattern}'"
    sed -i -e "/${checkPattern}/d" "${filteredWordsFile}"
  done
  cp "${filteredWordsFile}" "${filteredWordsFile2}"
  logDebug "Second pass filter ensuring no char/clue occurs too many times"
  logFilteredHitCount
}

# Now filter using clue paths, composing base patterns derived all possible
# 3-clue, 2-clue, and 1-clues path paths into robust patterns that all valid
# words must satisify. There will still be potential false positives that make
# it through, but a large probabilistic majority of candidate words should be
# filtered out. This will help make the downstream computationally expensive
# path-finding search/filter faster.
# Note that this works since currently all words are at least 4 chars long and
# currently all clues are 1-char except for a single 2-char clue. If we allow
# for longer clues or multiple 2-char clues, or if we allow shorter words, the
# following filtering will stop being valid.

function performAdjacentCluesFiltering() {
  # First, read the grid into an associative array with keys/value pairs of the form
  #   ij=CLUE_VALUE
  # denotiving value CLUE_VALUE at row i, column j, 1 <= i,j <= 5
  # The 5x5 structure of the grid file, and the validity of clues, should already
  # have been verified elsewhere.
  declare -i i=1
  # Map from "ij" -> "<clue at row i, col j>"
  declare -A gridCoorToValueMap
  logDebug "Setting up 'gridCoorToValueMap' associative array:"
  while read i1 i2 i3 i4 i5; do
    gridCoorToValueMap["${i}1"]="${i1}"
    gridCoorToValueMap["${i}2"]="${i2}"
    gridCoorToValueMap["${i}3"]="${i3}"
    gridCoorToValueMap["${i}4"]="${i4}"
    gridCoorToValueMap["${i}5"]="${i5}"
    logDebug "${i}1=${gridCoorToValueMap[${i}1]} ${i}2=${gridCoorToValueMap[${i}2]} ${i}3=${gridCoorToValueMap[${i}3]} ${i}4=${gridCoorToValueMap[${i}4]} ${i}5=${gridCoorToValueMap[${i}5]}"
    i+=1
  done < "${GRID}"
  logDebug "Grid file contains (reminder/for comparison):"
  logDebug "\n$(cat "${GRID}")"

  # Extract the patterns for all 2-clue paths
  declare -i i j
  twoCluePathRegexFile="${outputDir}/two-clue-path.regex-list.${gridBasename}.txt"
  touch "${twoCluePathRegexFile}"
  logDebug "Creating regex file '${twoCluePathRegexFile}'"
  logDebug "  It will contain patterns composed from two clues that form a valid path"
  function addPattern2char() {
    logDebug "${pattern}"
    echo "${pattern}" >> "${twoCluePathRegexFile}"
  }
  function forwardsAndBackwards2char() {
    pattern="${a}${b}"; addPattern2char
    pattern="${b}${a}"; addPattern2char
    logDebug
  }
  # Horizontal pairs
  for i in {1..5}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      forwardsAndBackwards2char
    done
  done
  # Vertical pairs
  for i in {1..4}; do
    for j in {1..5}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      forwardsAndBackwards2char
    done
  done
  # Forward diagonal pairs
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      forwardsAndBackwards2char
    done
  done
  # Backward diagonal pairs
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      forwardsAndBackwards2char
    done
  done

  # Extract the patterns for all 3-clue paths
  declare -i i j
  threeCluePathRegexFile="${outputDir}/three-clue-path.regex-list.${gridBasename}.txt"
  touch "${threeCluePathRegexFile}"
  logDebug "Creating regex file '${threeCluePathRegexFile}'"
  logDebug "  It will contain patterns composed from three clues that form a valid path"
  function addPattern3char() {
    logDebug "${pattern}"
    echo "${pattern}" >> "${threeCluePathRegexFile}"
  }
  function forwardsAndBackwards3char() {
    pattern="${a}${b}${c}"; addPattern3char
    pattern="${c}${b}${a}"; addPattern3char
    logDebug
  }
  function permutations3char() {
    pattern="${a}${b}${c}"; addPattern3char
    pattern="${a}${c}${b}"; addPattern3char
    pattern="${b}${a}${c}"; addPattern3char
    pattern="${b}${c}${a}"; addPattern3char
    pattern="${c}${a}${b}"; addPattern3char
    pattern="${c}${b}${a}"; addPattern3char
    logDebug
  }
  # Shapes: 'o' means part of the path; 'x' means not part of the path
  # o o o
  # Just forward and backward; no arbitary permutations
  for i in {1..5}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+0))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o
  # o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..5}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+0))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug

  # o o
  #     o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #     o
  # o o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+0))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o   o
  #   o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+0))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #   o
  # o   o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o
  #   o o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #   o o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+0))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug

  #   o
  # o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+0))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o
  #   o
  #   o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+1))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o
  #   o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+0))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #   o
  # o
  #   o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+1))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #   o
  #   o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+0))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  # o
  # o
  #   o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+1))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug

  # o
  #   o
  #     o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+2))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug
  #     o
  #   o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..3}; do
    for j in {1..3}; do
      a="${gridCoorToValueMap["$((i+0))$((j+2))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+2))$((j+0))"]}"
      forwardsAndBackwards3char
    done
  done
  logDebug

  #   o
  # o o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      permutations3char
    done
  done
  logDebug
  # o
  # o o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      permutations3char
    done
  done
  logDebug
  # o o
  # o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      permutations3char
    done
  done
  logDebug
  # o o
  #   o
  # Just forward and backward; no arbitary permutations
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      c="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      permutations3char
    done
  done
  logDebug

  # Compose the extracted sets of 1-clue, 2-clue, and 3-clue path patterns into
  # their respective 1-clue, 2-clue, and 3-clue regular expressions.  Then
  # compose these together into a handful of robust patterns that all valid
  # words must be able to pass. False positives may make it through so further,
  # even more robust filtering/testing will be required.
  singleLetterClues=$(sed -e 's@\<[a-z]\{2,\}\>@@g' -e 's@ @\n@g' "${GRID}" | sort -u | xargs | sed -e 's@ @@g')
  multiLetterClues=$( sed -e 's@\<[a-z]\>@@g'       -e 's@ @\n@g' "${GRID}" | sort -u | xargs | sed -e 's@ @|@g')
  singleCluePattern_all="([${singleLetterClues}]|${multiLetterClues})"
  doubleCluePattern_all="($(sort "${twoCluePathRegexFile}"   |  xargs | sed -e 's@ @|@g'))"
  tripleCluePattern_all="($(sort "${threeCluePathRegexFile}" |  xargs | sed -e 's@ @|@g'))"

  # Compose 2-clues patterns together, allowing for an optional additional
  # 1-clue pattern since words may require an even or odd number of clues.
  pattern2="^${doubleCluePattern_all}+${singleCluePattern_all}?$"
  pattern3="^${singleCluePattern_all}?${doubleCluePattern_all}+$"

  # Compose 3-clue patterns together, allowing for an optional additional
  # 2-clue or 1-clue pattern since words may require 0, 1, or 2 clues mod 3.
  pattern4="^${tripleCluePattern_all}+(${doubleCluePattern_all}|${singleCluePattern_all})?$"
  pattern5="^(${doubleCluePattern_all}|${singleCluePattern_all})?${tripleCluePattern_all}+$"

  logDebug "singleLetterClues:     ${singleLetterClues}"
  logDebug "multiLetterClues:      ${multiLetterClues}"
  logDebug "singleCluePattern_all: ${singleCluePattern_all}"
  logDebug "doubleCluePattern_all: ${doubleCluePattern_all}"
  logDebug "Regex file composed from 2-clue paths:"
  logDebug "\n$(cat ${twoCluePathRegexFile})"
  logDebug "Regex file composed from 3-clue paths:"
  logDebug "\n$(cat ${threeCluePathRegexFile})"
  logDebug "Third pass filtering applying the following patterns to words list file:"
  logDebug "pattern2:\n  '${pattern2}'"
  logDebug "pattern3:\n  '${pattern3}'"
  logDebug "pattern4:\n  '${pattern4}'"
  logDebug "pattern5:\n  '${pattern5}'"

  # Apply the new filter pattern
  # TODO: centralize the definition/declaration of all filtered word list files
  set +e
  egrep "${pattern2}" "${filteredWordsFile}" | egrep "${pattern3}" | egrep "${pattern4}" | egrep "${pattern5}" > "${filteredWordsFile3}"
  if [ $? -eq 2 ]; then
    logError "There was an error with the grep command just run"
    exitCode=$((exitCode | GREP_ERROR))
  fi
  checkExitCode
  set -e
  cp "${filteredWordsFile3}" "${filteredWordsFile}"
  logFilteredHitCount
}

# Switch from using regex patterns to filter down results to
# actually checking each remaining possibility directly.

# First, read the grid into an associative array with keys/value pairs of the form
#   CLUE_VALUE="ab cd ..."
# denotiving value CLUE_VALUE at row,column pairs "ab", "cd", etc.
# The 5x5 structure of the grid file, and the validity of clues, should already
# have been verified elsewhere.
declare -i i=1;
declare -A gridMap
function setupGridMap() {
  logDebug "Setting up 'gridMap' associative array:"
  while read i1 i2 i3 i4 i5; do
    gridMap["${i1}"]+=" ${i}1"; gridMap["${i1}"]="${gridMap[${i1}]# }"
    gridMap["${i2}"]+=" ${i}2"; gridMap["${i2}"]="${gridMap[${i2}]# }"
    gridMap["${i3}"]+=" ${i}3"; gridMap["${i3}"]="${gridMap[${i3}]# }"
    gridMap["${i4}"]+=" ${i}4"; gridMap["${i4}"]="${gridMap[${i4}]# }"
    gridMap["${i5}"]+=" ${i}5"; gridMap["${i5}"]="${gridMap[${i5}]# }"
    logDebug "Processed row '${i}', updating"
    logDebug "  ${i1} -> '${gridMap[${i1}]}'"
    logDebug "  ${i2} -> '${gridMap[${i2}]}'"
    logDebug "  ${i3} -> '${gridMap[${i3}]}'"
    logDebug "  ${i4} -> '${gridMap[${i4}]}'"
    logDebug "  ${i5} -> '${gridMap[${i5}]}'"
    i+=1
  done < "${GRID}"
  logDebug "Final gridMap contents:"
  for clue in "${!gridMap[@]}"; do
    logDebug "  ${clue} -> '${gridMap[${clue}]}'"
  done
  logDebug "Grid file contains (reminder/for comparison):"
  logDebug "\n$(cat "${GRID}")"
}

declare -i len=0
declare -i pos=0
# pathObject values are space-delimited strings containing 'path pathLen prefix'
# where 'path' is a sequence of sequentially adjacent coordinates on the
# grid that spells out the 'prefix' or length 'pathLen' for the current word
# e.g., '112122 4 inni'
declare -a pathObjects=()
function initCheckWordVars() {
  len=${#word}
  pos=0
  pathObjects=()
}

# TODO: generalize for arbitrary-length clues
function setInitialPaths() {
  if [ ${#pathObjects[@]} -gt 0 ]; then
    return
  fi

  pos=0;
  local char1="${word:${pos}:1}"
  local char2="${word:${pos}:2}"
  local char1_positions="${gridMap[${char1}]:-}"
  local char2_positions="${gridMap[${char2}]:-}"
  logDebug "Checking chars at position '${pos}':"
  logDebug "  char1 '${char1}'  -> '${char1_positions}'"
  logDebug "  char2 '${char2}' -> '${char2_positions}'"
  pathObjects=(${char1_positions} ${char2_positions})
  i=0
  # Encode each path as "<concatenated string of clue positions> <total length thus far>"
  for char1_position in ${char1_positions}; do
    pathObjects[${i}]="${char1_position} 1 ${char1}"
    i+=1
  done
  for char2_position in ${char2_positions}; do
    pathObjects[${i}]="${char2_position} 2 ${char2}"
    i+=1
  done
  logDebug "  Num Starting Paths: ${#pathObjects[@]}"
  for path in "${pathObjects[@]}"; do
    logDebug "    ${path}"
  done
}

# Handle a single path object and attempt to extend using
# clues of length N (if any).
function extendSinglePathByCluesOfLengthN() {
  # Extract next N-char extension from $word
  declare ext="${word:${pos}:${N}}"
  logDebug "Checking ext '${ext}' at position '${pos}'"
  declare newPrefix="${prefix}${ext}"
  # Extract list (space-delimited string) of coordinates for ext
  nextPositions="${gridMap[${ext}]:-}"
  if [ -n "${nextPositions}" ]; then
    logDebug "Found at least one position to attempt to extend our paths from for ext '${ext}'"
    # At least one potential clue may be able to extend our current path.
    # But for each, we need to check that the clue coor hasn't been used
    # already and, if it hasn't, that it validly extends the current path
    logDebug "Inspecting positions '${nextPositions}' for ${N}-char extension '${ext}'"
    for nextPosition in ${nextPositions}; do
      logDebug "Inspecting position ${nextPosition}"
      newPathFound=false
      local usedPositions="$(echo ${path} | sed -e 's@\(..\)@\1 @g' | sed -e 's@ $@@' )"
      # Check it hasn't been used already in the current path
      previouslySeenPosition=false
      for usedPosition in ${usedPositions}; do
        logDebug "  Checking against used position ${usedPosition}"
        if [[ "${nextPosition}" == "${usedPosition}" ]]; then
          logDebug "  Invalid - position has already been used"
          previouslySeenPosition=true
          break
        fi
      done
      if ${previouslySeenPosition}; then
        # Go to next nextPosition
        continue
      fi
      logDebug "    Valid - Position has not been used yet"
      # Check that it validly extends the current path
      logDebug "    Now check that it can extend the current path"
      declare -i nextPositionI="${nextPosition:0:1}"
      declare -i nextPositionJ="${nextPosition:1:1}"
      declare lastUsedPosition="${usedPositions: -2}"
      declare -i lastUsedPositionI="${lastUsedPosition:0:1}"
      declare -i lastUsedPositionJ="${lastUsedPosition:1:1}"
      logDebug "      Checking whether the putative next position '${nextPosition}' can extend from last used position '${lastUsedPosition}'"
      declare -i diffI=$((nextPositionI - lastUsedPositionI))
      declare -i diffJ=$((nextPositionJ - lastUsedPositionJ))
      if [ "${diffI}" -ge -1 -a "${diffI}" -le 1 ]; then
        if [ "${diffJ}" -ge -1 -a "${diffJ}" -le 1 ]; then
          # If all checks passed, append the extended path to newPathObjects array
          newPathFound=true
          # Keep track that we already know this prefix/word has a valid path.
          previouslySeenStrings["${newPrefix}"]="found"
          declare newPath="${path}${nextPosition}"
          # TODO: check, should this be "+1" or "+N" ???
          declare -i newPathLen=$((pathLen+N))
          newPathObject="${newPath} ${newPathLen} ${newPrefix}"
          logDebug "        SUCCESS - path extension FOUND: '${pathObj}' -> '${newPathObject}'"
          if [ ${newPathLen} -eq ${#word} ]; then
            logDebug "          This path completes the target word"
            # For now, stop at the first successful path rather than trying to find all paths
            # TODO: For this final relatively compute-intensive step,
            #       try seeing we can do a depth-first constructive search
            #       instead of breadth-first constructive search.
            break
          else
            logDebug "          This path does NOT complete the target word"
            logDebug "            Appending '${newPathObject}' to newPathObjects"
            newPathObjects+=("${newPathObject}")
          fi
        fi
      fi
      if ! ${newPathFound}; then
        logDebug "      FAILURE - path extension NOT found: '${pathObj}' -> void"
      fi
    done # extend path by N chars
  fi
}

# Loop through current path object and try extending each of them
function extendPaths() {
  logDebug "Attempting to extend pathObjects:"
  for pathObj in "${pathObjects[@]}"; do
    logDebug "  ${pathObj}"
  done # pathObj iteration

  declare -a newPathObjects=()
  declare -i pathLen
  for pathObj in "${pathObjects[@]}"; do
    # Parse path object
    read path pathLen prefix < <(echo "${pathObj}")
    pos=${pathLen}
    logDebug "Inspecting partial path '${path}' of length '${pos}' (${prefix}) for word '${word}'"
    for N in {1..2}; do
      if [ -n "${previouslySeenStrings["${word}"]:-}" ]; then
        logDebug "  A path for word '${word}' has been found. Stopping search"
        newPathObjects=()
        break 2
      fi
      if [ ${pathLen} -le $((len-N)) ]; then
        logDebug "Attempting to extend word by '${N}' chars"
        extendSinglePathByCluesOfLengthN
      else
        logDebug "  There are not enough chars left in word '${word}' after '${prefix}' to extend '${N}' chars"
      fi
    done
    logDebug "\n"
  done # pathObj iteration
  # Now replace $pathObjects from $newPathObjects
  pathObjects=()
  declare -i i=0
  for newPathObject in "${newPathObjects[@]}"; do
    pathObjects[i]="${newPathObject}"
    i+=1
  done

  # Log ending set of pathObjects
  logDebug "Set of pathObjects after this extension attempt:"
  for pathObj in "${pathObjects[@]}"; do
    logDebug "  ${pathObj}"
  done # pathObj iteration

  logDebug "\n"
}

function checkWordAgainstGrid() {
  logDebug "Checking word '${word}'"
  initCheckWordVars
  setInitialPaths
  logDebug "\n"
  while [ ${#pathObjects[@]} -gt 0 ]; do
    extendPaths
  done
  checkIfPathHasBeenFoundForCurrentWord
}

function addWordToFinalList() {
  echo "${word}" >> "${filteredWordsFile4}"
}

function checkIfPathHasBeenFoundForCurrentWord() {
  logDebug "Checking whether a path has been found for '${word}'"

  if [ -n "${previouslySeenStrings["${word}"]:-}" ]; then
    logDebug "SUCCESS - found a path for '${word}'"
    logDebug "${word}"
    addWordToFinalList
  else
    logDebug "FAILURE - no paths found for '${word}'"
  fi
}

# Loop over words (lines) in words files
declare -A previouslySeenStrings
function performFullPathSearchFiltering() {
  setupGridMap
  touch "${filteredWordsFile4}"
  while read word; do
    if [ -n "${previouslySeenStrings["${word}"]:-}" ]; then
      logDebug "Checking word '${word}'"
      logDebug "  '${word}' has been seen before - bypassing logic to search for paths"
      checkIfPathHasBeenFoundForCurrentWord
    else
      checkWordAgainstGrid
    fi
  done < <(tac "${filteredWordsFile}")
  # TODO: maintain iterative sequence of these filtered word lists better
  sort "${filteredWordsFile4}" > "${filteredWordsFile}"
}

# Create copy of filtered word file, but where the words are sorted by length first
function createFileSortedByLength() {
  for w in $(cat "${filteredWordsFile}"); do
    echo "${#w} ${w}";
  done | sort -n 1> "${filteredWordsFileSortedByLength}"
}

# Score a words file
declare -i score=0
function scoreWordsFile() {
  wordsFile="${1}"
  logInfo
  logInfo "Scoring words file '${wordsFile}'"
  declare -A scoringMap=(
    [4]=1
    [5]=2
    [6]=3
    [7]=5
    [8,]=11
  )
  declare -i valuePerWord numWords inc
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
  logInfo "  ${scoreString} $(basename "${filteredWordsFile}")"
  logScore "  ${scoreString}"
}

function logCompletion() {
  logInfo
  logInfo "Done"
  logInfo "Final results available in file"
  logInfo "  ${filteredWordsFile}"
  logFilteredHitCount
}

function performTestingCheck() {
  if ${testing}; then
    logTesting "Performing testing check"
    logTesting "  Checking file: '${filteredWordsFile}'"
    logTesting "  against  file: ${EXPECTED_TEST_FILE}"
    declare fullDiff="$(diff "${EXPECTED_TEST_FILE}" "${filteredWordsFile}" | grep '^[<>]')"
    declare -i diffLen="$(echo "${fullDiff}" | wc -l)"
    logTesting "Diff between files has '${diffLen}' lines"
    if [ -z "${fullDiff}" ]; then
      logTesting "  Test SUCCESS"
    else
      logError "  Test FAILURE - the files did not match (${diffLen} lines different)"
      logError "diff \"${EXPECTED_TEST_FILE}\" \"${filteredWordsFile}\""
      logError "\n${fullDiff}"
    fi
  fi
}

function main() {
  setupLoggingFunctions
  turnColorOn
  parseArgs "${@}"
  setupOutputDir
  selectDefaultFileOptionLists
  promptUserForGridAndWordFiles
  validateFiles
  createInitialFilteredWordsFile
  performCharCountsFiltering
  performAdjacentCluesFiltering
  performFullPathSearchFiltering
  createFileSortedByLength
  logCompletion
  scoreWordsFile "${filteredWordsFile}"
  performTestingCheck
}

main "${@}"
