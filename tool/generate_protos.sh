#!/usr/bin/env sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

exec protoc \
  --plugin=protoc-gen-dart="$project_dir/tool/protoc-gen-dart" \
  --dart_out=lib/generated/proto \
  --proto_path=protos \
  common.proto
