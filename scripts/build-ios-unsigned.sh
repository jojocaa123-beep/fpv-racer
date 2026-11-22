#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
build_dir="${FPV_IOS_OUTPUT_DIR:-$project_dir/build/ios}"
if [[ -e "$build_dir" ]]; then
    echo "Escolha um FPV_IOS_OUTPUT_DIR novo para preservar exports anteriores." >&2
    exit 1
fi
mkdir -p "$build_dir"
mkdir -p "$project_dir/build"
touch "$project_dir/build/.gdignore"
run_logged() {
    local log_path="$1"
    shift
    if "$@" > "$log_path" 2>&1; then
        return 0
    else
        local failure_code=$?
        echo "Etapa falhou (codigo $failure_code). Ultimas linhas de $log_path:" >&2
        tail -n 100 "$log_path" >&2
        return "$failure_code"
    fi
}
run_logged "$build_dir/import.log" "$godot_bin" --headless --editor --path "$project_dir" --import
run_logged "$build_dir/export.log" "$godot_bin" --headless --path "$project_dir" --export-release 'iOS Unsigned' \
    "$build_dir/FPVRacer.ipa"
test -d "$build_dir/FPVRacer.xcodeproj"
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Projeto Xcode exportado: $build_dir/FPVRacer.xcodeproj"
    echo "A compilacao do aplicativo ainda precisa do Xcode em macOS. Nenhum IPA foi gerado nesta etapa."
    exit 0
fi
command -v xcodebuild >/dev/null
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
run_logged "$build_dir/xcode.log" xcodebuild -project "$build_dir/FPVRacer.xcodeproj" -scheme FPVRacer \
    -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "$build_dir/DerivedData" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
    build
shopt -s nullglob
apps=("$build_dir"/DerivedData/Build/Products/Release-iphoneos/*.app)
if [[ ${#apps[@]} -ne 1 ]]; then
    echo "Esperado um unico .app na saida do Xcode." >&2
    exit 1
fi
mkdir -p "$build_dir/Payload"
ditto "${apps[0]}" "$build_dir/Payload/$(basename -- "${apps[0]}")"
ditto -c -k --keepParent "$build_dir/Payload" "$build_dir/FPVRacer-unsigned.ipa"
echo "IPA SEM ASSINATURA: $build_dir/FPVRacer-unsigned.ipa"
echo "Ainda requer assinatura pessoal e instalacao para teste no iPhone."
