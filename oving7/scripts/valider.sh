#!/usr/bin/env bash
# valider.sh - kjører fmt, validate, TFLint og Checkov. Ingen "set -e": alle
# kontrollene kjøres selv om en tidligere feiler, slik at du ser ALLE feilene
# i én kjøring i stedet for å rette én om gangen.

set -u

# Til terraform-projects/ (her: oving7/), uansett hvor skriptet startes fra.
cd "$(dirname "$0")/.."

TERRAFORM_MAPPER=(
  "stacks/network"
  "modules/network"
)

FEILET=()

echo "== terraform fmt -check =="
if ! terraform fmt -check -recursive; then
  FEILET+=("fmt")
fi

for mappe in "${TERRAFORM_MAPPER[@]}"; do
  echo "== terraform validate ($mappe) =="
  (
    cd "$mappe" || exit 1
    terraform init -backend=false -input=false >/dev/null 2>&1
    terraform validate
  )
  if [ $? -ne 0 ]; then
    FEILET+=("validate:$mappe")
  fi
done

echo "== TFLint =="
tflint --init >/dev/null 2>&1
if ! tflint --recursive --config "$(pwd)/.tflint.hcl"; then
  FEILET+=("tflint")
fi

echo "== Checkov =="
if ! checkov -d .; then
  FEILET+=("checkov")
fi

echo
if [ ${#FEILET[@]} -eq 0 ]; then
  echo "Alle kontrollene er grønne."
  exit 0
else
  echo "Feilet: ${FEILET[*]}"
  exit 1
fi
