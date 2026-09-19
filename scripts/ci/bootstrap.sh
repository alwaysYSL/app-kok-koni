#!/usr/bin/env bash
set -euo pipefail

readonly FLUTTER_VERSION="3.44.4"
readonly FLUTTER_COMMIT="ad70ec4617166f1c38e5d2bfd388af71fda14f06"
readonly ANDROID_TOOLS_ARCHIVE="commandlinetools-linux-16111833_latest.zip"
readonly ANDROID_TOOLS_SHA1="e025545c62a8e64c7559119566a569fb1dec5f60"
readonly SDK_ROOT="${CI_PROJECT_DIR}/.ci-sdk"
readonly FLUTTER_ROOT="${SDK_ROOT}/flutter"
readonly ANDROID_ROOT="${SDK_ROOT}/android"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]] || [[ "$(git -C "${FLUTTER_ROOT}" rev-parse HEAD 2>/dev/null || true)" != "${FLUTTER_COMMIT}" ]]; then
  rm -rf "${FLUTTER_ROOT}"
  git clone --branch "${FLUTTER_VERSION}" --depth 1 https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
fi

actual_flutter_commit="$(git -C "${FLUTTER_ROOT}" rev-parse HEAD)"
if [[ "${actual_flutter_commit}" != "${FLUTTER_COMMIT}" ]]; then
  echo "Flutter commit tidak sesuai pin: ${actual_flutter_commit}" >&2
  exit 1
fi

if [[ ! -x "${ANDROID_ROOT}/cmdline-tools/latest/bin/sdkmanager" ]]; then
  archive_path="${SDK_ROOT}/${ANDROID_TOOLS_ARCHIVE}"
  extracted_path="${SDK_ROOT}/android-tools-extracted"
  rm -rf "${extracted_path}"
  mkdir -p "${ANDROID_ROOT}/cmdline-tools" "${extracted_path}"
  curl --fail --location --retry 3 "https://dl.google.com/android/repository/${ANDROID_TOOLS_ARCHIVE}" --output "${archive_path}"
  echo "${ANDROID_TOOLS_SHA1}  ${archive_path}" | sha1sum --check --status
  unzip -q "${archive_path}" -d "${extracted_path}"
  rm -rf "${ANDROID_ROOT}/cmdline-tools/latest"
  mv "${extracted_path}/cmdline-tools" "${ANDROID_ROOT}/cmdline-tools/latest"
  rm -f "${archive_path}"
  rm -rf "${extracted_path}"
fi

export PATH="${FLUTTER_ROOT}/bin:${ANDROID_ROOT}/cmdline-tools/latest/bin:${ANDROID_ROOT}/platform-tools:${PATH}"
export ANDROID_HOME="${ANDROID_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_ROOT}"

set +o pipefail
yes | sdkmanager --licenses >/dev/null
license_status="${PIPESTATUS[1]}"
set -o pipefail
if [[ "${license_status}" -ne 0 ]]; then
  exit "${license_status}"
fi

sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358"
