#!/usr/bin/env bash
set -euo pipefail
tools_dir="${1:?Informe um diretorio novo para as ferramentas.}"
if [[ -e "$tools_dir" ]]; then echo "O diretorio de ferramentas deve ser novo." >&2; exit 1; fi
mkdir -p "$tools_dir"
case "$(uname -s)" in
    Linux)
        editor_name=Godot_v4.7.2-stable_linux.x86_64.zip
        editor_hash=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
        godot_bin="$tools_dir/Godot_v4.7.2-stable_linux.x86_64"
        ;;
    Darwin)
        editor_name=Godot_v4.7.2-stable_macos.universal.zip
        editor_hash=c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e
        godot_bin="$tools_dir/Godot.app/Contents/MacOS/Godot"
        ;;
    *) echo "Sistema nao suportado neste helper de CI." >&2; exit 1 ;;
esac
verify_hash() {
    python3 - "$1" "$2" <<'PY'
from pathlib import Path
import hashlib, sys
checksum = hashlib.sha256()
with Path(sys.argv[1]).open('rb') as source:
    for chunk in iter(lambda: source.read(1024*1024), b''): checksum.update(chunk)
if checksum.hexdigest() != sys.argv[2]: raise SystemExit('SHA256 do download nao corresponde ao release oficial.')
PY
}
curl -fsSL --retry 2 "https://github.com/godotengine/godot/releases/download/4.7.2-stable/$editor_name" -o "$tools_dir/editor.zip"
verify_hash "$tools_dir/editor.zip" "$editor_hash"
unzip -q "$tools_dir/editor.zip" -d "$tools_dir"
rm "$tools_dir/editor.zip"
chmod u+x "$godot_bin"
if [[ "$(uname -s)" == "Darwin" ]]; then
    curl -fsSL --retry 2 https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz -o "$tools_dir/templates.tpz"
    verify_hash "$tools_dir/templates.tpz" f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011
    python3 - "$tools_dir/templates.tpz" "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import shutil, sys
target = Path(sys.argv[2]); target.mkdir(parents=True, exist_ok=True)
with ZipFile(sys.argv[1]) as archive:
    name = next(name for name in archive.namelist() if name.endswith('/ios.zip'))
    with archive.open(name) as source, (target/'ios.zip').open('wb') as output:
        shutil.copyfileobj(source, output)
PY
    rm "$tools_dir/templates.tpz"
fi
printf '%s\n' "$godot_bin" > "$tools_dir/godot-path.txt"
"$godot_bin" --version
