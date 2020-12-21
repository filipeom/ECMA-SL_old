#!/usr/bin/env bash
printf " -------------------------------\n"
printf " \tECMA-SL JS Test262 Tool\n"
printf " -------------------------------\n"

RED='\033[0;31m'   	# RED
NC='\033[0m'       	# No Color
GREEN='\033[0;32m' 	# GREEN
YELLOW='\33[1;33m' 	# YELLOW
BLINK1='\e[5m'
BLINK2='\e[25m'	   	#BLINK
INV='\e[7m'         #INVERTED
LGREEN='\e[102m'
BOLD='\e[1m'


function usage {
  echo -e "Usage: $(basename $0) [OPTION]... [-dfir]"
  echo -e '
  -d <dir>   Directory containing test files.
             All the tests available in the directory are executed.
  -f <file>  File to test.
  -i <file>  File containing the list of files to test.
  -r <dir>   Directory containing test files and/or directories.
             If the directories contain other directories, all the tests available in those directories are also executed.

  Options:
  -E         Enable logging to file the tests executed with errors. File is "errors.log"
  -F         Enable logging to file the failed tests. File is "failures.log"
  -O         Enable logging to file the passed tests. File is "oks.log"'
  exit 1
}

function writeToFile() {
  local output_file=$1
  local params=("$@")
  unset params[0] # is the output file

  for s in "${params[@]}"; do
    echo -e "$s" >> $output_file
  done
}

function logStatusToFiles() {
  if [ $LOG_ERRORS -eq 1 ]; then
    cat /dev/null > $LOG_ERRORS_FILE
    for error in "${log_errors_arr[@]}"; do
      echo "$error" >> $LOG_ERRORS_FILE
    done
  fi

  if [ $LOG_FAILURES -eq 1 ]; then
    cat /dev/null > $LOG_FAILURES_FILE
    for failure in "${log_failures_arr[@]}"; do
      echo "$failure" >> $LOG_FAILURES_FILE
    done
  fi

  if [ $LOG_OKS -eq 1 ]; then
    cat /dev/null > $LOG_OKS_FILE
    for ok in "${log_oks_arr[@]}"; do
      echo "$ok" >> $LOG_OKS_FILE
    done
  fi
}

# Checks:
# - file is a valid ES5 test (search for the key "es5id" in the frontmatter)
# - file doesn't use the built-in eval function
# - file is not a negative test (search for the key "negative" in the frontmatter)
function checkConstraints() {
  FILENAME=$1

  METADATA=$2
  # check if it's a es5id test
  if [[ $(echo -e "$METADATA" | awk '/es6id:|esid:/ {print $0}') != "" ]]; then
    printf "${BOLD}${YELLOW}${BLINK2}${INV}NOT EXECUTED: not ES5 test${NC}\n"

    checkConstraints_return="${FILENAME} | **NOT EXECUTED** | Is not a ES5 test"
    return 1
  fi
  # check if it uses/contains a call the built-in eval function
  if [[ $(echo -e "$METADATA" | awk '/eval\(/ {print $0}') != "" ]]; then
    printf "${BOLD}${YELLOW}${BLINK2}${INV}NOT EXECUTED: eval test${NC}\n"

    checkConstraints_return="${FILENAME} | **NOT EXECUTED** | Is an \"eval\" test"
    return 1
  fi
  # check if it's a negative test
  if [[ $(echo -e "$METADATA" | awk '/negative:/ {print $2}') != "" ]]; then
    printf "${BOLD}${YELLOW}${BLINK2}${INV}NOT EXECUTED: negative test${NC}\n"

    checkConstraints_return="${FILENAME} | **NOT EXECUTED** | ${isnegative}"
    return 1
  fi

  return 0
}

function handleSingleFile() {
  # increment number of files being tested.
  incTotal

  FILENAME=$1
  printf "Testing ${FILENAME} ... "

  METADATA=$(cat "$FILENAME" | awk '/\/\*---/,/---\*\//')

  checkConstraints $FILENAME "$METADATA"

  if [[ $? -ne 0 ]]; then
    # increment number of tests not executed
    incNotExecuted

    test_result=("$checkConstraints_return")
    return
  fi

  #echo "3.1. Copy contents to temporary file"
  cat /dev/null > "output/main262.js"
  if [[ $(echo -e "$METADATA" | awk '/flags: \[onlyStrict\]/ {print $1}') != "" ]]; then
    echo "\"use strict\";" >> output/main262.js
  fi
  cat "test/test262/environment/harness.js" >> output/main262.js
  cat "${FILENAME}" >> output/main262.js

  if [ $? -ne 0 ]; then
    exit 1
  fi

  #echo "3.2. Create the AST of the program in the file FILENAME and compile it to a \"Plus\" ECMA-SL program"
  cd "../JS2ECMA-SL"
  JS2ECMASL=$(node src/index.js -i ../implementation/output/main262.js -o ../implementation/output/test262_ast.esl 2>&1)
  cd "../implementation"

  if [[ "${JS2ECMASL}" != "The file has been saved!" ]]; then
    printf "${BOLD}${RED}${INV}ERROR${NC}\n"

    # increment number of tests with error
    incError

    if [ $LOG_ERRORS -eq 1 ]; then
      log_errors_arr+=("$FILENAME")
    fi

    ERROR_MESSAGE=$(echo -e "$JS2ECMASL" | head -n 1)

    test_result=("$FILENAME" "**ERROR**" "$ERROR_MESSAGE" "")
    return
  fi

  #echo "3.4. Compile program written in \"Plus\" to \"Core\""
  ECMASLC=$(./main.native -mode c -i output/test262.esl -o output/core.esl 2>&1)

  if [ $? -ne 0 ]; then
    printf "${BOLD}${RED}${INV}ERROR${NC}\n"

    # increment number of tests with error
    incError

    if [ $LOG_ERRORS -eq 1 ]; then
      log_errors_arr+=("$FILENAME")
    fi

    ERROR_MESSAGE=$(echo -e "$ECMASLC" | head -n 1)

    test_result=("$FILENAME" "**ERROR**" "$ERROR_MESSAGE" "")
    return
  fi

  # Record duration of the program interpretation
  declare -i start_time=$(date +%s%N)

  #echo "3.5. Evaluate program and write the computed heap to the file heap.json."
  ECMASLCI=$(./main.native -mode ci -i output/core.esl -h heap.json 2>&1)

  local EXIT_CODE=$?

  # Calc duration
  declare -i end_time=$(date +%s%N)
  declare -i duration=$((end_time-start_time))
  # The amount of zeros is necessary because we're dealing with seconds and nanoseconds
  duration_str=$(echo $duration | awk '{printf "%02dh:%02dm:%06.3fs\n", $0/3600000000000, $0%3600000000000/60000000000, $0/1000000000%60}')

  if [ $EXIT_CODE -eq 0 ]; then
    printf "${BOLD}${GREEN}${INV}OK!${NC}\n"

    # increment number of tests successfully executed
    incOk

    if [ $LOG_OKS -eq 1 ]; then
      log_oks_arr+=("$FILENAME")
    fi

    test_result=("$FILENAME" "_OK_" "" "$duration_str")
  elif [ $EXIT_CODE -eq 1 ]; then
    printf "${BOLD}${RED}${BLINK1}${INV}FAIL${NC}\n"

    # increment number of tests failed
    incFail

    if [ $LOG_FAILURES -eq 1 ]; then
      log_failures_arr+=("$FILENAME")
    fi

    test_result=("$FILENAME" "**FAIL**" "$RESULT" "$duration_str")
  else
    printf "${BOLD}${RED}${INV}ERROR${NC}\n"

    # increment number of tests with error
    incError

    if [ $LOG_ERRORS -eq 1 ]; then
      log_errors_arr+=("$FILENAME")
    fi

    ERROR_MESSAGE=$(echo -e "$ECMASLCI" | tail -n 1)

    test_result=("$FILENAME" "**ERROR**" "$ERROR_MESSAGE" "$duration_str")
  fi

  if [ $LOG_ENTIRE_EVAL_OUTPUT -eq 1 ]; then
    # Output of the execution is written to the file result.txt
    echo "Writing interpretation output to file..."
    echo "$ECMASLCI" > result.txt
  fi
}

function testFiles() {
  local files=($@)

  for file in "${files[@]}"; do
    if [ -f $file ]; then
      # Test file
      handleSingleFile $file
    else
      echo "Ignoring \"$file\". It's not a valid file."
      continue
    fi

    # Write results to file
    # transform returned results in a string ready to be written to file
    local str="${test_result[0]}"
    for s in "${test_result[@]:1}"; do
      str+=" | "
      str+=$s
    done
    files_results+=("$str")
  done
}

function handleFiles() {
  local output_file=$1
  local files=($@)
  unset files[0]

  # log evaluation output to a file
  if [[ ${#files[@]} -eq 1 ]]; then
    LOG_ENTIRE_EVAL_OUTPUT=1
  fi

  # Write header to file
  local params=()
  if [[ ${#files[@]} > 1 ]]; then
    params+=("## Testing multiple files")
  else
    params+=("## Testing single file")
  fi
  params+=("---")
  writeToFile $output_file "${params[@]}"

  testFiles "${files[@]}"

  local params=()
  params+=("### Summary")
  params+=("OK | FAIL | ERROR | NOT EXECUTED | Total")
  params+=(":---: | :---: | :---: | :---: | :---:")
  params+=("$ok_tests | $fail_tests | $error_tests | $not_executed_tests | $total_tests")
  params+=("### Individual results")
  params+=("File path | Result | Observations | Duration")
  params+=("--- | :---: | :---: | ---")
  params+=("${files_results[@]}")

  writeToFile $output_file "${params[@]}"
}

function handleSingleDirectory() {
  local output_file=$1
  local dir=$2
  local lastChar=${dir: -1}
  if [[ $lastChar != "/" ]]; then
    dir=$dir"/"
  fi

  # Tests existence of JS files and avoids logging errors to the console.
  ls $dir*.js > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    testFiles "$(ls $dir*.js)"
  fi

  if [[ $RECURSIVE -ne 0 ]]; then
    # Tests existence of directories in this folder and avoids logging errors to the console.
    ls -d $dir*/ > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      handleDirectories $output_file "$(ls -d $dir*/)"
    fi
  fi
}

function handleDirectories() {
  local output_file=$1
  local dirs=($@)
  unset dirs[0]

  for dir in "${dirs[@]}"; do
    if [ -d $dir ]; then
      # Save current state of the dir counters.
      declare -i curr_dir_ok_tests=$dir_ok_tests
      declare -i curr_dir_fail_tests=$dir_fail_tests
      declare -i curr_dir_error_tests=$dir_error_tests
      declare -i curr_dir_not_executed_tests=$dir_not_executed_tests
      declare -i curr_dir_total_tests=$dir_total_tests
      # Reset directories' counters
      resetDirCounters
      # Test directory
      files_results=()
      handleSingleDirectory $output_file $dir

      if [[ $dir_total_tests -ne 0 ]]; then
        local params=()
        params+=("## Summary of the tests executed in \"$dir\"")
        params+=("OK | FAIL | ERROR | NOT EXECUTED | Total")
        params+=(":---: | :---: | :---: | :---: | :---:")
        params+=("$dir_ok_tests | $dir_fail_tests | $dir_error_tests | $dir_not_executed_tests | $dir_total_tests")
        params+=("")
        params+=("### Individual results")
        params+=("File path | Result | Observations | Duration")
        params+=("--- | :---: | :---: | ---")
        params+=("${files_results[@]}")
        params+=("")

        writeToFile $output_file "${params[@]}"
      fi

      # Set directories' counters to the sum of the values before handling directory and the values obtained after handling directory
      dir_ok_tests+=$curr_dir_ok_tests
      dir_fail_tests+=$curr_dir_fail_tests
      dir_error_tests+=$curr_dir_error_tests
      dir_not_executed_tests+=$curr_dir_not_executed_tests
      dir_total_tests+=$curr_dir_total_tests
    else
      echo "Ignoring \"$dir\". It's not a valid directory"
      continue
    fi
  done
}

function incTotal() {
  total_tests+=1
  dir_total_tests+=1
}

function incOk() {
  ok_tests+=1
  dir_ok_tests+=1
}

function incFail() {
  fail_tests+=1
  dir_fail_tests+=1
}

function incError() {
  error_tests+=1
  dir_error_tests+=1
}

function incNotExecuted() {
  not_executed_tests+=1
  dir_not_executed_tests+=1
}

function resetDirCounters() {
  dir_total_tests=0
  dir_ok_tests=0
  dir_fail_tests=0
  dir_error_tests=0
  dir_not_executed_tests=0
}


function processFromInputFile() {
  local INPUT_FILES=($@)

  handleFiles $OUTPUT_FILE "$(cat ${INPUT_FILES[@]})"

  logStatusToFiles
}

function processRecursively() {
  local dirs=($@)
  RECURSIVE=1

  handleDirectories $OUTPUT_FILE ${dirs[@]}

  logStatusToFiles
}

function processDirectories() {
  local dirs=($@)

  handleDirectories $OUTPUT_FILE ${dirs[@]}

  logStatusToFiles
}

#
# BEGIN
#
if [[ ${#} -eq 0 ]]; then
   usage
fi

# Initialise global variables
# Counters
declare -i total_tests=0
declare -i ok_tests=0
declare -i fail_tests=0
declare -i error_tests=0
declare -i not_executed_tests=0
# Counters used in the directories
declare -i dir_total_tests=0
declare -i dir_ok_tests=0
declare -i dir_fail_tests=0
declare -i dir_error_tests=0
declare -i dir_not_executed_tests=0

declare checkConstraints_return=""
declare -a results=()
declare -a files_results=()
declare -a test_result=()

declare -i RECURSIVE=0
declare -r OUTPUT_FILE="logs/results_$(date +%d%m%yT%H%M%S).md"

declare -i LOG_ENTIRE_EVAL_OUTPUT=0

declare -i LOG_ERRORS=0
declare -i LOG_FAILURES=0
declare -i LOG_OKS=0
declare -r LOG_ERRORS_FILE="logs/errors_$(date +%d%m%yT%H%M%S).log"
declare -r LOG_FAILURES_FILE="logs/failures_$(date +%d%m%yT%H%M%S).log"
declare -r LOG_OKS_FILE="logs/oks_$(date +%d%m%yT%H%M%S).log"
declare -a log_errors_arr=()
declare -a log_failures_arr=()
declare -a log_ok_arr=()

# Empty the contents of the output file
cat /dev/null > $OUTPUT_FILE
# Check that "logs" directory exists and, if not, create it
if [ ! -d "logs" ]; then
  mkdir "logs"
fi
# Check that "output" directory exists and, if not, create it
if [ ! -d "output" ]; then
  mkdir "output"
fi


#echo "1. Create the file that will be compiled from \"Plus\" to \"Core\" in step 3.4."
echo "import \"output/test262_ast.esl\";" > "output/test262.esl"
echo "import \"ES5_interpreter/ESL_Interpreter.esl\";" >> "output/test262.esl"
echo "function main() {
  x := buildAST();
  ret := JS_Interpreter_Program(x);
  return ret
}" >> "output/test262.esl"


#echo "2. Compile the ECMA-SL language"
# OCAMLMAKE=$(make)
make

if [ $? -ne 0 ]
then
  # echo $OCAMLMAKE
  exit 1
fi

echo ""

# Define list of arguments expected in the input
optstring=":EFOd:f:i:r:"

declare -a dDirs=() # Array that will contain the directories to use with the arg "-d"
declare -a fFiles=() # Array that will contain the files to use with the arg "-f"
declare -a iFiles=() # Array that will contain the files to use with the arg "-i"
declare -a rDirs=() # Array that will contain the directories to use with the arg "-r"

while getopts ${optstring} arg; do
  case $arg in
    E) LOG_ERRORS=1 ;;
    F) LOG_FAILURES=1 ;;
    O) LOG_OKS=1 ;;
    d) dDirs+=("$OPTARG") ;;
    f) fFiles+=("$OPTARG") ;;
    i) iFiles+=("$OPTARG") ;;
    r) rDirs+=("$OPTARG") ;;

    ?)
      echo "Invalid option: -${OPTARG}."
      echo ""
      usage
      ;;
  esac
done

# Record duration
declare -i startTime=$(date +%s%N)

if [ ${#dDirs[@]} -ne 0 ]; then
  processDirectories ${dDirs[@]}
fi

if [ ${#fFiles[@]} -ne 0 ]; then
  handleFiles $OUTPUT_FILE ${fFiles[@]}
fi

if [ ${#iFiles[@]} -ne 0 ]; then
  processFromInputFile ${iFiles[@]}
fi

if [ ${#rDirs[@]} -ne 0 ]; then
  processRecursively ${rDirs[@]}
fi

declare -i endTime=$(date +%s%N)
declare -i duration=$((endTime-startTime))
echo ""
# The amount of zeros is necessary because we're dealing with seconds and nanoseconds
echo $duration | awk '{printf "Execution duration: %02dh:%02dm:%06.3fs\n", $0/3600000000000, $0%3600000000000/60000000000, $0/1000000000%60}'

