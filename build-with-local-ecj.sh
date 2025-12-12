#!/usr/bin/env bash
set -euo pipefail

# This script builds the processor + dependency once, then compiles the
# reproducer with javac and multiple ECJ versions to pinpoint when the
# regression first appears.

# ---------------- configuration ----------------

JAVA_RELEASE="${JAVA_RELEASE:-21}"
ECJ_VERSION_DEFAULTS=("3.39.0" "3.40.0" "3.41.0" "3.42.0" "3.43.0" "3.44.0")
ECJ_VERSION_STRING="${ECJ_VERSIONS:-${ECJ_VERSION_DEFAULTS[*]}}"
IFS=' ' read -r -a ECJ_VERSIONS <<< "${ECJ_VERSION_STRING}"

ECJ_GROUP_PATH="org/eclipse/jdt"
ECJ_ARTIFACT="ecj"
ECJ_DIR=".ecj"

GROUP_ID="com.example.annotationbug"
VERSION="1.0-SNAPSHOT"

AP_ARTIFACT="AnnotationProcessorBugAnnotationProcessor"
DEP_ARTIFACT="AnnotationProcessorBugDependency"
REP_ARTIFACT="AnnotationProcessorBugReproducer"

SRC_ROOT="${REP_ARTIFACT}/src/main/java"
SOURCES_FILE="target/ecj-sources.txt"
BUG_PATTERN="Expected a class enclosing element"

# ---------------- helper functions ----------------

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

download_ecj() {
  local version="$1"
  local jar_name="ecj-${version}.jar"
  local jar_path="${ECJ_DIR}/${jar_name}"
  local url="https://repo1.maven.org/maven2/${ECJ_GROUP_PATH}/${ECJ_ARTIFACT}/${version}/${jar_name}"

  if [ ! -f "${jar_path}" ]; then
    log "Downloading ECJ ${version} from Maven Central"
    mkdir -p "${ECJ_DIR}"
    curl -fL "${url}" -o "${jar_path}"
  fi

  echo "${jar_path}"
}

require_file() {
  local path="$1"
  local description="$2"
  if [ ! -e "${path}" ]; then
    echo "ERROR: ${description} not found: ${path}" >&2
    exit 1
  fi
}

collect_sources() {
  mkdir -p target
  find "${SRC_ROOT}" -name '*.java' -print > "${SOURCES_FILE}"

  if [ ! -s "${SOURCES_FILE}" ]; then
    echo "ERROR: no Java sources found under ${SRC_ROOT}" >&2
    exit 1
  fi
}

run_and_record() {
  local label="$1"
  local log_file="$2"
  shift 2

  mkdir -p "$(dirname "${log_file}")"

  {
    printf 'Command:'
    printf ' %q' "$@"
    printf '\n\n'
  } > "${log_file}"

  local status="success"
  if ! "$@" >>"${log_file}" 2>&1; then
    status="fail"
  fi

  local bug="no"
  if grep -q "${BUG_PATTERN}" "${log_file}"; then
    bug="yes"
  fi

  RESULTS+=("${label}|${status}|${bug}|${log_file}")
  log "${label}: status=${status}, bug=${bug}, log=${log_file}"
}

run_javac() {
  local out_dir="target/javac-classes"
  local gen_dir="target/javac-generated-sources"
  local log_file="target/javac.log"

  mkdir -p "${out_dir}" "${gen_dir}"

  local cmd=(javac
    --release "${JAVA_RELEASE}"
    -processorpath "${AP_JAR}"
    -processor processor.ReproducerProcessor
    -cp "${DEP_JAR}:${AP_JAR}"
    -s "${gen_dir}"
    -d "${out_dir}"
    @"${SOURCES_FILE}"
  )

  run_and_record "javac" "${log_file}" "${cmd[@]}"
}

run_ecj_version() {
  local version="$1"
  local jar_path
  jar_path=$(download_ecj "${version}")

  local out_dir="target/ecj-${version}-classes"
  local gen_dir="target/ecj-${version}-generated-sources"
  local log_file="target/ecj-${version}.log"

  mkdir -p "${out_dir}" "${gen_dir}"

  local cmd=(java
    -cp "${jar_path}"
    org.eclipse.jdt.internal.compiler.batch.Main
    --release "${JAVA_RELEASE}"
    -processorpath "${AP_JAR}"
    -processor processor.ReproducerProcessor
    -cp "${DEP_JAR}:${AP_JAR}"
    -s "${gen_dir}"
    -d "${out_dir}"
    @"${SOURCES_FILE}"
  )

  run_and_record "ecj-${version}" "${log_file}" "${cmd[@]}"
}

print_summary() {
  echo
  echo "Summary (bug=yes when processor reported unexpected enclosing element)"
  printf '%-12s %-8s %-4s %s\n' "compiler" "status" "bug" "log"
  printf '%-12s %-8s %-4s %s\n' "--------" "------" "---" "---"

  local first_bug_version=""

  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r label status bug log_file <<< "${entry}"
    printf '%-12s %-8s %-4s %s\n' "${label}" "${status}" "${bug}" "${log_file}"
    if [[ "${label}" == ecj-* && "${bug}" == "yes" && -z "${first_bug_version}" ]]; then
      first_bug_version="${label#ecj-}"
    fi
  done

  echo
  if [ -n "${first_bug_version}" ]; then
    echo "Regression first observed in ECJ ${first_bug_version} (per run order above)."
  else
    echo "No ECJ version in the test set triggered the processor error."
  fi
}

# ---------------- sanity checks ----------------

if [ ! -f "pom.xml" ]; then
  echo "ERROR: run this script from the parent directory containing pom.xml" >&2
  exit 1
fi

command -v javac >/dev/null 2>&1 || { echo "ERROR: javac not found on PATH" >&2; exit 1; }

# ---------------- build Maven inputs ----------------

log "Building annotation processor and dependency with Maven"
mvn -DskipTests -pl "${AP_ARTIFACT},${DEP_ARTIFACT}" -am clean install

BASE_REPO="$HOME/.m2/repository/$(printf "%s" "$GROUP_ID" | tr '.' '/')"
AP_JAR="${BASE_REPO}/${AP_ARTIFACT}/${VERSION}/${AP_ARTIFACT}-${VERSION}.jar"
DEP_JAR="${BASE_REPO}/${DEP_ARTIFACT}/${VERSION}/${DEP_ARTIFACT}-${VERSION}.jar"

require_file "${AP_JAR}" "annotation processor jar"
require_file "${DEP_JAR}" "dependency jar"

log "Verifying dependency jar contains dependency/BinaryDependency.class"
if ! jar tf "${DEP_JAR}" | grep -q '^dependency/BinaryDependency.class$'; then
  echo "ERROR: dependency jar does not contain dependency/BinaryDependency.class" >&2
  exit 1
fi

# ---------------- collect sources ----------------

collect_sources
RESULTS=()

# ---------------- run compilers ----------------

log "Compiling with javac"
run_javac

for version in "${ECJ_VERSIONS[@]}"; do
  log "Compiling with ECJ ${version}"
  run_ecj_version "${version}"
done

print_summary
