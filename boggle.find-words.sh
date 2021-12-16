#!/bin/bash

# File on errors. Undefined vars count as errors.
set -eu

# Logging levels
   debug=true;
    info=true;
    warn=true;
   error=true;
critical=true;

# Coloration
TPUT_RESET="$(tput sgr0)";

 FAINT="$(tput dim)";
BRIGHT="$(tput bold)";

   RED_FG="$(tput setaf  1)";
 GREEN_FG="$(tput setaf  2)";
YELLOW_FG="$(tput setaf 11)";
  CYAN_FG="$(tput setaf 14)";
PURPLE_FG="$(tput setaf 93)";

BRIGHT_RED_FG="${BRIGHT}${RED_FG}";
FAINT_GREEN_FG="${FAINT}${GREEN_FG}";
BRIGHT_YELLOW_FG="${BRIGHT}${YELLOW_FG}";
BRIGHT_CYAN_FG="${BRIGHT}${CYAN_FG}";
BRIGHT_PURPLE_FG="${BRIGHT}${PURPLE_FG}";

   RED_BG="$(tput setab 9)";
 GREEN_BG="$(tput setab 2)";
YELLOW_BG="$(tput setab 3)";

START_COLOR="${BRIGHT_RED_FG}";
GUESS_COLOR="${BRIGHT_YELLOW_FG}";
BOARD_COLOR="${FAINT_GREEN_FG}";

FLAGGED_START_HIGHLIGHT="${GREEN_BG}";
FLAGGED_GUESS_HIGHLIGHT="${RED_BG}";

   DEBUG_COLOR="${BRIGHT_CYAN_FG}";
    INFO_COLOR="${BRIGHT_PURPLE_FG}";
    WARN_COLOR="${BRIGHT_YELLOW_FG}";
   ERROR_COLOR="${BRIGHT_RED_FG}";
CRITICAL_COLOR="${YELLOW_BG}${BRIGHT_RED_FG}";
  HEADER_COLOR="${YELLOW_BG}${BRIGHT_RED}";

# Logging functions
function logDebug()    { if $debug;     then echo -e "${DEBUG_COLOR}DEBUG:"       "${@}${TPUT_RESET}"; fi; }
function logInfo()     { if $info;      then echo -e "${INFO_COLOR}INFO:"         "${@}${TPUT_RESET}"; fi; }
function logWarn()     { if $warn;      then echo -e "${WARN_COLOR}WARN:"         "${@}${TPUT_RESET}"; fi; }
function logError()    { if $error;     then echo -e "${ERROR_COLOR}ERROR:"       "${@}${TPUT_RESET}"; fi; }
function logCritical() { if $critical;  then echo -e "${CRITICAL_COLOR}CRITICAL:" "${@}${TPUT_RESET}"; fi; }
function logHeader()   {                     echo -e "${HEADER_COLOR}"            "${@}${TPUT_RESET}"; }

# Declare some files for later selection
GRID_01="${PWD}/data/grids/sample-boggle-grid.01.txt"
GRID_03="${PWD}/data/grids/sample-boggle-grid.03.txt"
GRID_02="${PWD}/data/grids/sample-boggle-grid.02.txt"

AMERICAN_ENGLISH_WORDS="${PWD}/data/words/american-english.words"
SCRABBLE_BOGGLE_WORDS="${PWD}/data/words/scrabble.boggle.words"
SCRABBLE_ALL_WORDS="${PWD}/data/words/scrabble.all.words"

BOGGLE_DICE_TXT="${PWD}/data/dice/boggle-dice.txt"

# Exit codes (to be OR'd together ('|'))
declare -i FILE_MISSING=1
declare -i FILE_UNREADABLE=2

# Select specific files to use this run
GRID="${GRID_01}"
WORDS="${AMERICAN_ENGLISH_WORDS}"
logInfo "Selected grid  file '${GRID}'"
logInfo "Selected words file '${WORDS}'"

# Verify chosen files exist
declare -i exitCode=0
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

# Exit if one of the above checks failed
if [ ${exitCode} -gt 0 ]; then
  logError
  logError "An error was encountered. Exiting early with exit code ${exitCode}"
  exit ${exitCode}
fi

# Construct basic regex pattern from grid file
multiLetterClues=$(sed -e 's@\<[a-z]\>@@g' -e 's@ @\n@g' "${GRID}" | sort | xargs | sed -e 's@ @|@g')
logDebug "multiLetterClues: '${multiLetterClues}' (should only be one)"
singleLetterClues=$(sed -e 's@\<[a-z]\{2,\}\>@@g' -e 's@ @\n@g' "${GRID}" | sort -u | xargs | sed -e 's@ @@g')
logDebug "singleLetterClues: '${singleLetterClues}'"
pattern="^([${singleLetterClues}]|${multiLetterClues})+\$"
logDebug "pattern: '${pattern}'"

# Run basic pattern agains word list save results to a tmp file
tmpFile="$(mktemp -p tmp/ filtered-words.XXX.txt)"
egrep --color=never "${pattern}" "${WORDS}" > "${tmpFile}"
numHits=$(wc -l "${tmpFile}")
numTrimmedHits=5
prefixHits="$(head -${numTrimmedHits} "${tmpFile}" | sed -e 's@^@  @')"
suffixHits="$(tail -${numTrimmedHits} "${tmpFile}" | sed -e 's@^@  @')"
logDebug "Number of hits found using the basic pattern: ${numHits}"
logDebug "\n${prefixHits}\n  ...\n${suffixHits}"

echo
logInfo "Done"
