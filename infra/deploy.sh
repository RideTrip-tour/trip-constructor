#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="$SCRIPT_DIR/stacks"

if [[ ! -d "$STACKS_DIR" ]]; then
  echo "Stacks directory not found: $STACKS_DIR" >&2
  exit 1
fi

stack_files=(
  "$STACKS_DIR/data-stack.yml"
  "$STACKS_DIR/gateway-stack.yml"
  "$STACKS_DIR/app-stack.yml"
  "$STACKS_DIR/frontend-stack.yml"
)

missing=0
for stack_file in "${stack_files[@]}"; do
  if [[ ! -f "$stack_file" ]]; then
    echo "Missing stack file: $stack_file" >&2
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  exit 1
fi

for stack_file in "${stack_files[@]}"; do
  base_name="$(basename "$stack_file")"
  stack_name="${base_name%.*}"
  stack_name="${stack_name%-stack}"

  echo "Deploying stack '$stack_name' from $stack_file"
  docker stack deploy -c "$stack_file" "$stack_name"
done
