#!/bin/bash
set -eoxu pipefail

cd "$(dirname "$0")"

for i in *.dot
do
    dot -Tsvg "$i" -o "${i%.dot}.svg"
done