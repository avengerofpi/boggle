#!/bin/bash

# Exit on errors. Undefined vars count as errors.
set -eu

# Logging levels
   debug=false;
    info=true;
    warn=true;
   error=true;
scoreLog=true;

# Add argument parsing
# Based on suggestions from https://drewstokes.com/bash-argument-parsing
declare randomFiles=false
declare GRID="" WORDS=""
function parseArgs() {
  while (( "$#" )); do
    case "$1" in
      -g|--grid-file)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          GRID="$2"
          logDebug "Choosing GRID file '${GRID}'"
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -w|--words-file)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          WORDS="$2"
          logDebug "Choosing WORDS file '${WORDS}'"
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -r|--random-files)
        randomFiles=true
        logDebug "Choosing random files instead of prompting user (unless file was chosen by another argument)"
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
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
      *) # positional parameters - unsupported
        logError "Encountered a positional param, but no positional params are supported"
        exit 2
        #shift
        ;;
    esac
  done
}

# Output setup
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
      logDebug "  Does not exist yet. We will use '${outputDir}' as the output dir"
      outputDir="${putative_outputDir}"
      break;
    fi;
  done;

  if [ -z "${outputDir}" ]; then
    logError "Failed to choose a usable output dir."
    exitCode=99
  fi
  checkExitCode

  mkdir -p "${outputDir}"
  touch "${outputDir}/${datetime}.txt"
}

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

   DEBUG_COLOR="${BRIGHT_CYAN_FG}";
    INFO_COLOR="${BRIGHT_YELLOW_FG}";
    WARN_COLOR="${BRIGHT_PURPLE_FG}";
   ERROR_COLOR="${BRIGHT_RED_FG}";
   SCORE_COLOR="${YELLOW_BG}${BRIGHT_RED_FG}";

# Logging functions
function logDebug()    { if $debug;     then echo -e "${DEBUG_COLOR}DEBUG:"       "${@}${TPUT_RESET}"; fi; }
function logInfo()     { if $info;      then echo -e "${INFO_COLOR}INFO:  "       "${@}${TPUT_RESET}"; fi; }
function logWarn()     { if $warn;      then echo -e "${WARN_COLOR}WARN:  "       "${@}${TPUT_RESET}"; fi; }
function logError()    { if $error;     then echo -e "${ERROR_COLOR}ERROR:"       "${@}${TPUT_RESET}"; fi; }
function logScore()    { if $scoreLog;  then echo -e "${SCORE_COLOR}SCORE:"       "${@}${TPUT_RESET}"; fi; }

# Declare some files for later selection
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
      line+="${clue} "
    done
    line="${line% }"
    logDebug "Appending line '${line}' to grid file"
    echo "${line}" >> "${GRID}"
  done
  logInfo "Random grid file generated:"
  logInfo "\n$(cat "${GRID}")"
  cp "${GRID}" "${PWD}/data/grids/random/"
}

# Select specific files to use this run
function promptUserForGridAndWordFiles() {
  GRID_PROMPT="Choose the grid file to use: "
  WORDS_PROMPT="Choose the words file to use: "
  # Select grid file
  if [ -z "${GRID}" ]; then
    if ${randomFiles}; then
      generateRandomGrid
    else
      PS3="${GRID_PROMPT}"
      select GRID in "${GRID_FILES[@]}"; do
        if [ -n "${GRID}" ]; then
          break
        else
          echo "Try again. Focus!"
        fi
      done
    cp "${GRID}" "${outputDir}"
    fi
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

# Exit if exitCode has been set, log and exit if so
declare -i exitCode=0
function checkExitCode() {
  if [ ${exitCode} -gt 0 ]; then
    logError
    logError "An error was encountered. Exiting early with exit code ${exitCode}"
    exit ${exitCode}
  fi
}

# Perform checks/validations before rest of code runs

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
  gridLinePattern="^[a-z]+( [a-z]+){4}+\$"
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

# Start fast filtering of words file

function logFilteredHitCount() {
  numHits=$(wc -l "${filteredWordsFile}" | awk '{print $1}')
  logInfo "Number of filtered hits found: '${numHits}'"
}

# Create writable copy of starting words list file.
# We will filter on this copy rather than on the original.
declare filteredWordsFile=""
function createInitialFilteredWordsFile() {
  gridBasename="$(basename "${GRID}")"
  wordsBasename="$(basename "${WORDS}")"
  filteredWordsFile="${outputDir}/words.${gridBasename}---${wordsBasename}---filtered.txt"
  logInfo "Saving filtered words to file: ${filteredWordsFile}"
  cp "${WORDS}" "${filteredWordsFile}"
  chmod u+w "${filteredWordsFile}"
  logFilteredHitCount
}

# Add a pattern to filter out hits with too many of any char (or multi-char)

# First, get counts of each clue. Be careful to not trim too much, e.g. if
# there's a multi-char clue 'in' that occurs once as well as single-char clues
# 'i' and 'n', then it may be possible (depending on the actual grid) for 'in'
# to occur more than once.
function performClueCountsFiltering() {
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
    sed -i -e "/${checkPattern}/d" "${filteredWordsFile}"
  done
  logDebug "Second pass filter ensuring no char/clue occurs too many times"
  logFilteredHitCount
}

# Now process pairs of adjacent clues.

# First, read the grid into an associative array with keys/value pairs of the form
#   ij=CLUE_VALUE
# denotiving value CLUE_VALUE at row i, column j, 1 <= i,j <= 5
# The 5x5 structure of the grid file, and the validity of clues, should already
# have been verified elsewhere.
declare filteredWordsFile2=""
function performAdjacentCluesFiltering() {
  declare -i i=1
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
  done < <(cat "${GRID}")
  logDebug "Grid file contains (reminder/for comparison):"
  logDebug "\n$(cat "${GRID}")"

  # Start building the possible regexes from pairs of clues
  declare -i i j
  regexFile="${outputDir}/regex-list.${gridBasename}.txt"
  touch "${regexFile}"
  logDebug "Creating regex file '${regexFile}'"
  logDebug "  For now it will just contain patterns composed from pairs of adjacent clues"
  # Horizontal pairs
  for i in {1..5}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      echo "${a}${b}" >> "${regexFile}"
      echo "${b}${a}" >> "${regexFile}"
    done
  done
  # Vertical pairs
  for i in {1..4}; do
    for j in {1..5}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      echo "${a}${b}" >> "${regexFile}"
      echo "${b}${a}" >> "${regexFile}"
    done
  done
  # Forward diagonal pairs
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+1))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+0))"]}"
      echo "${a}${b}" >> "${regexFile}"
      echo "${b}${a}" >> "${regexFile}"
    done
  done
  # Backward diagonal pairs
  for i in {1..4}; do
    for j in {1..4}; do
      a="${gridCoorToValueMap["$((i+0))$((j+0))"]}"
      b="${gridCoorToValueMap["$((i+1))$((j+1))"]}"
      echo "${a}${b}" >> "${regexFile}"
      echo "${b}${a}" >> "${regexFile}"
    done
  done

  # Construct regex
  # Only handles single-char and double-char clues correctly and only when exactly one double-char clue
  # occurs in the grid (might also handle the 'no double-char clue' case), which is standard in real boggle. If we
  # generalize to clue lengths > 2 chars or to multiple double-char clues, this logic will need changing.
  singleLetterClues=$(sed -e 's@\<[a-z]\{2,\}\>@@g' -e 's@ @\n@g' "${GRID}" | sort -u | xargs | sed -e 's@ @@g')
  singleCluePattern_1char="([${singleLetterClues}])"
  doubleCluePattern_all="($(sort "${regexFile}" |  xargs | sed -e 's@ @|@g'))"
  pattern2="^${doubleCluePattern_all}+${singleCluePattern_1char}?$"
  pattern3="^${singleCluePattern_1char}?${doubleCluePattern_all}+$"

  logDebug "singleLetterClues:         ${singleLetterClues}"
  logDebug "singleCluePattern_1char: ${singleCluePattern_1char}"
  logDebug "doubleCluePattern_all:   ${doubleCluePattern_all}"
  logDebug "Regex file composed from pairs of adjacent clues:"
  logDebug "\n$(cat ${regexFile})"
  logDebug "Third pass filtering applying the following patterns to words list file:"
  logDebug " '${pattern2}'"
  logDebug " '${pattern3}'"

  # Apply the new filter pattern
  filteredWordsFile2="${outputDir}/words.${gridBasename}---${wordsBasename}---filtered2.txt"
  set +e
  egrep "${pattern2}" "${filteredWordsFile}" | egrep "${pattern3}" > "${filteredWordsFile2}"
  if [ $? -eq 2 ]; then
    logError "There was an error with the grep command just run"
    exitCode=$((exitCode | GREP_ERROR))
  fi
  checkExitCode
  set -e
  mv "${filteredWordsFile2}" "${filteredWordsFile}"
  logFilteredHitCount
}

# Switch from using regex patterns to filter down results to
# actually checking each (remaining) possibility directly.

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
  done < <(cat "${GRID}")
  logDebug "Final gridMap contents:"
  for clue in "${!gridMap[@]}"; do
    logDebug "  ${clue} -> '${gridMap[${clue}]}'"
  done
  logDebug "Grid file contains (reminder/for comparison):"
  logDebug "\n$(cat "${GRID}")"
}

declare -i len=0
declare -i pos=0
# Path objects are space-delimited strings containing 'path pathLen prefix'
# where 'path' is a sequence of sequentially adjacent coordinates on the
# grid that spells out the 'prefix' or length 'pathLen' for the current word
# e.g., '112122 4 inni'
declare -a pathObjects=()
declare -a wordSuccessfulPaths=()
# Map from prefixes (of words) to string-encoded space-delimited arrays of paths
# e.g., prefixToPathMap["inni"]="112122 42524334"
declare -A prefixToPathMap
declare -i wordSuccessfulPathsI
function initCheckWordVars() {
  len=${#word}
  pos=0
  pathObjects=()
  wordSuccessfulPaths=()
  wordSuccessfulPathsI=0
}

function extractPathsForLongestPrefix() {
  # Check if a prefix for the current word has an entry in prefixToPathMap
  declare -i prefixLen
  declare prefix=""
  local prefix pathList path pathLen prefix
  # Work backwords to we can exit immediately if a hit if found
  logDebug "Checking whether any prefixes have been seen before (and have VALID paths)"
  for prefixLen in $(seq ${len} -1 1); do
    prefix="${word:0:${prefixLen}}"
    pathList="${prefixToPathMap[${prefix}]:-}"
    logDebug "  Checking prefix '${prefix}'"
    if [ -n "${pathList}" ]; then
      logDebug "    We have indeed encountered prefix '${prefix}' before"
      # Parse pathList into pathObjects
      declare -i i=0
      for path in ${pathList}; do
        pathLen=$(( ${#path} / 2 ))
        pathObject="${path} ${pathLen} ${prefix}"
        logDebug "      Adding path object '${pathObject}' to the pathObjects list"
        pathObjects[${i}]="${pathObject}"
        i+=1
      done
      break
    fi
  done
  logDebug "  Number of previously found initial paths for prefix '${prefix}' of '${word}': ${#pathObjects[@]}"
}

# TODO: generalize for arbitrary-length clues
function setInitialPaths() {
  extractPathsForLongestPrefix
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
  # Initialize prefixToPathMap values
  logDebug "Initializing prefixToPathMap for '${char1}' and '${char2}'"
  prefixToPathMap["${char1}"]=""
  prefixToPathMap["${char2}"]=""
  i=0
  # Encode each path as "<concatenated string of clue positions> <total length thus far>"
  for char1_position in ${char1_positions}; do
    prefixToPathMap["${char1}"]+=" ${char1_position}"
    pathObjects[${i}]="${char1_position} 1 ${char1}"
    i+=1
  done
  for char2_position in ${char2_positions}; do
    prefixToPathMap["${char2}"]+=" ${char2_position}"
    pathObjects[${i}]="${char2_position} 2 ${char2}"
    i+=1
  done
  logDebug "  prefixToPathMap[${char1}] = '${prefixToPathMap[${char1}]}'"
  logDebug "  prefixToPathMap[${char2}] = '${prefixToPathMap[${char2}]}'"
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
  prefixToPathMap["${newPrefix}"]="${prefixToPathMap[${newPrefix}]:-}"
  logDebug "  Initializing (or reaffirming) prefixToPathMap for '${newPrefix}'"
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
      for usedPosition in ${usedPositions}; do
        logDebug "  Checking against used position ${usedPosition}"
        if [[ "${nextPosition}" == "${usedPosition}" ]]; then
          logDebug "  Invalid - position has already been used"
          break 2
        fi
      done
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
          declare newPath="${path}${nextPosition}"
          declare -i newPathLen=$((pathLen+1))
          newPathObject="${newPath} ${newPathLen} ${newPrefix}"
          logDebug "        SUCCESS - path extension FOUND: '${newPathObject}'"
          # Update helper prefixToPathMap. If we are making proper use of this helper
          # map, we should avoid any situation where a prefix or a new path repeat
          # and so we should not need to check for redundancy.
          # TODO: (maybe) add a debug check for redundancy
          prefixToPathMap["${newPrefix}"]+=" ${newPath}"
          if [ ${newPathLen} -eq ${#word} ]; then
            logDebug "          This path (len=${newPathLen}) completes the target word (len=${len})"
            logDebug "          Appending wordSuccessfulPaths[${wordSuccessfulPathsI}]=${newPathObject}"
            wordSuccessfulPaths[${wordSuccessfulPathsI}]="${newPathObject}"
            wordSuccessfulPathsI+=1
            # For now, stop at the first successful path rather than trying to find all paths
            # CANCEL THE SHORT-CIRCUIT HERE, so we can grab all the "prefix paths"
            #break
          else
            newPathObjects[${newPathI}]="${newPathObject}"
            newPathI+=1
          fi
        fi
      fi
      if ! ${newPathFound}; then
        logDebug "      FAILURE - path extension NOT found"
      fi
    done # extend path by N chars
  fi
  logDebug "  prefixToPathMap[${newPrefix}] = '${prefixToPathMap[${newPrefix}]}'"
}

# Loop through current path object and try extending each of them
function extendPaths() {
  logDebug "Attempting to extend pathObjects:"
  for pathObj in "${pathObjects[@]}"; do
    logDebug "  ${pathObj}"
  done # pathObj iteration

  declare -a newPathObjects=()
  declare -i newPathI=0
  declare -i pathLen
  for pathObj in "${pathObjects[@]}"; do
    # Parse path object
    read path pathLen prefix < <(echo "${pathObj}")
    pos=${pathLen}
    logDebug "Inspecting partial path '${path}' of length '${pos}' (${prefix}) for word '${word}'"
    for N in {1..2}; do
      if [ ${pathLen} -le $((len-N)) ]; then
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
  declare -i numWordSuccessfulPaths=${#wordSuccessfulPaths[@]};
  if [ ${numWordSuccessfulPaths} -gt 0 ]; then
    logDebug "SUCCESS - found ${numWordSuccessfulPaths} valid paths for '${word}'"
    logDebug "${word}"
    echo "${word}" >> "${filteredWordsFile2}"
  else
    logDebug "FAILURE - no paths found for word '${word}'"
  fi
  logDebug
}

# Loop over words (lines) in words files
# Reuse filteredWordsFil2
function performFullPathSearchFiltering() {
  touch "${filteredWordsFile2}"
  while read word; do
    checkWordAgainstGrid
  done < <(cat "${filteredWordsFile}")
  mv "${filteredWordsFile2}" "${filteredWordsFile}"
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

function main() {
  parseArgs "${@}"
  setupOutputDir
  selectDefaultFileOptionLists
  promptUserForGridAndWordFiles
  validateFiles
  createInitialFilteredWordsFile
  performClueCountsFiltering
  performAdjacentCluesFiltering
  setupGridMap
  performFullPathSearchFiltering
  logCompletion
  scoreWordsFile "${filteredWordsFile}"
}

main "${@}"
