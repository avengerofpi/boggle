#!/bin/bash

# Exit on errors. Undefined vars count as errors.
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

# Select specific files to use this run
GRID="${GRID_01}"
WORDS="${AMERICAN_ENGLISH_WORDS}"
logInfo "Selected grid  file '${GRID}'"
logInfo "Selected words file '${WORDS}'"

# Exit codes (to be OR'd together ('|'))
declare -i FILE_MISSING=1
declare -i FILE_UNREADABLE=2

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
gridBasename="$(basename "${GRID}")"
wordsBasename="$(basename "${WORDS}")"
tmpFile="tmp/${wordsBasename}---${gridBasename}---filtered---$(date +"%F-%Hh%Mm%Ss").txt"
logInfo "Saving filtered words to file '${tmpFile}'"
egrep --color=never "${pattern}" "${WORDS}" > "${tmpFile}"

function logFilteredHitCount() {
  numHits=$(wc -l "${tmpFile}" | awk '{print $1}')
  logDebug "Number of hits found using the basic pattern: '${numHits}' (${tmpFile})"
}
logFilteredHitCount
numTrimmedHits=5
prefixHits="$(head -${numTrimmedHits} "${tmpFile}" | sed -e 's@^@  @')"
suffixHits="$(tail -${numTrimmedHits} "${tmpFile}" | sed -e 's@^@  @')"
logDebug "\n${prefixHits}\n  ...\n${suffixHits}"

# Add a pattern to filter out hits with too many of any char (or multi-char)

# First, get counts of each clue. Be careful to not trim too much, e.g. if
# there's a multi-char clue 'in' that occurs once as well as single-char clues
# 'i' and 'n', then it may be possible (depending on the actual grid) for 'in'
# to occur more than once.
declare -A clueCnts
for c in {a..z}; do
  clueCnts["${c}"]="0";
done
# In order to udpate the array clueCnts from within the while loop, use process
# substitution instead of a pipeline
# https://stackoverflow.com/questions/9985076/bash-populate-an-array-in-loop
#   "Every command in a pipeline receives a copy of the shell's execution
#     environment, so a while loop would populate a copy of the array, and when
#     the while loop completes, that copy disappears"
while read cnt clue; do
  logDebug "Found clue '${clue}' (cnt: '${cnt}')"
  clueCnts["${clue}"]="${cnt}"
done < <(sed -e 's@\(\<[a-z]\)@\n\1@g' -e 's@ @\n@g' "${GRID}" | grep '[a-z]' | sort | uniq -c)

logDebug "clues:  '${!clueCnts[@]}'"
logDebug "counts: '${clueCnts[@]}'"

# Now process each clue.
for clue in "${!clueCnts[@]}"; do
  logDebug "Checking for too many hits against clue '${clue}' (cnt: 'checking...')"
  clueCnt="${clueCnts[${clue}]}"
  logDebug "Checking for too many hits against clue '${clue}' (cnt: '${clueCnt}')"
  # If clue is multi-char, check the individual chars cnts in case they all occur individually
  # Note that if I were to properly handle multi-char clues, I'd need to check all sub-stings.
  declare -i clueLen="${#clue}"
  declare -i maxExtraHits=0
  if [ "${clueLen}" -gt 1 ]; then
    logDebug "  This is a multi-char clue, it has '${clueLen}' chars"
    for i in $(seq 0 $((clueLen - 1))); do
      c="${clue:${i}:1}"
      declare -i cCnt="${clueCnts[${c}]}"
      logDebug "  Inspecting embedded char '${c}' (cnt: '${cCnt}')"
      if [ ${cCnt} -lt ${maxExtraHits} -o ${maxExtraHits} -eq 0 ]; then
        maxExtraHits=${cCnt}
        logDebug "    Updating maxExtraHits to '${maxExtraHits}'"
      fi
    done
  fi
  declare -i maxHits=${clueCnt}+${maxExtraHits}
  declare -i excessiveHits=${maxHits}+1
  logDebug "  maxHits: '${maxHits}'"
  checkPattern="^\(.*${clue}\)\{${excessiveHits},\}"
  logDebug "checkPattern: '${checkPattern}'"
  sed -i -e "/${checkPattern}/d" "${tmpFile}"
  logFilteredHitCount
done

echo
logInfo "Done"
