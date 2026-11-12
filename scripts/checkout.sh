#!/usr/bin/env bash
# Clones a sparse gion workspace.
#
# Environment (set by checkout/action.yml):
#   GION        path to the gion binary
#   REPOSITORY  owner/repo or a git URL
#   REF         branch, tag or commit (empty: the remote's HEAD)
#   PATHS       newline-separated paths to check out
#   PROJECTS    newline-separated project names from .gion/projects.toml
#               (PATHS and PROJECTS both empty: everything)
#   DIR         where to put the workspace
#   GIT         "false" to skip the local .git
set -euo pipefail

args=(clone "$REPOSITORY" "$DIR")
if [[ -n ${REF:-} ]]; then args+=(--ref "$REF"); fi
while IFS= read -r p; do
  p=${p#"${p%%[![:space:]]*}"}
  p=${p%"${p##*[![:space:]]}"}
  if [[ -n $p ]]; then args+=(--path "$p"); fi
done <<<"${PATHS:-}"
while IFS= read -r p; do
  p=${p#"${p%%[![:space:]]*}"}
  p=${p%"${p##*[![:space:]]}"}
  if [[ -n $p ]]; then args+=(--project "$p"); fi
done <<<"${PROJECTS:-}"
if [[ ${GIT:-true} == false ]]; then args+=(--no-git); fi

"$GION" "${args[@]}"
echo "path=$DIR" >>"$GITHUB_OUTPUT"
