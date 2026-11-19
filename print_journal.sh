#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Default configuration (Change to your preferred ICAO station ID)
AIRPORT="KJFK"
USER_AGENT="journal-printer/1.0 (+https://github.com/yourusername/yourrepo)"

usage() {
  echo "Usage: $0 [-s ICAO_CODE] [-h]"
  echo "  -s ICAO_CODE  4-character airport ICAO code (default: $AIRPORT)"
  echo "  -h            Display this help message"
  exit 1
}

while getopts ":s:h" opt; do
  case "$opt" in
    s) AIRPORT="$OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Normalize and validate the airport code (3-4 alphanumeric characters)
AIRPORT=$(printf '%s' "$AIRPORT" | tr '[:lower:]' '[:upper:]')
if [[ ! "$AIRPORT" =~ ^[A-Z0-9]{3,4}$ ]]; then
  echo "Error: Invalid station code '$AIRPORT'. Expected 3-4 alphanumeric characters." >&2
  exit 1
fi

# Create a temporary file for the print job and ensure cleanup on exit
TEMP_FILE=$(mktemp /tmp/journal_page.XXXXXX.txt)
trap 'rm -f "$TEMP_FILE"' EXIT

# Helper to wrap long lines cleanly at spaces (68 chars fits 1" left + 0.75" right margins)
wrap_text() {
  fold -s -w 68
}

# 1. Add the header: "Daily Journal" and the current date
{
  echo "Daily Journal"
  date +"%A, %B %d, %Y"
  echo "----------------------------------------"
  echo ""
} > "$TEMP_FILE"

# 2. Capture the weather and moon phase data
fetch_url() {
  local url="$1" attempt
  for (( attempt = 1; attempt <= 3; attempt++ )); do
    if curl -sS -f --max-time 20 -A "$USER_AGENT" "$url"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

WEATHER=$(fetch_url "https://aviationweather.gov/api/data/metar/?ids=${AIRPORT}&format=raw") || WEATHER="METAR unavailable"
TAF=$(fetch_url "https://aviationweather.gov/api/data/taf/?ids=${AIRPORT}&format=raw") || TAF="TAF unavailable"

# Clean carriage returns (\r), format TAF groups, wrap lines, and strip any empty lines
FORMATTED_METAR=$(printf '%s\n' "$WEATHER" | tr -d '\r' | wrap_text | awk 'NF')

FORMATTED_TAF=$(printf '%s\n' "$TAF" | tr -d '\r' \
  | sed -E 's/[[:space:]]+(FM[0-9]{6}|TEMPO|BECMG|PROB[0-9]{2})/\n  \1/g' \
  | wrap_text \
  | awk 'NF')

# Moon phase calculation
NOW=$(date +%s)
MOON_PHASE=$(awk -v now="$NOW" -v ref=947182440 -v cycle=2551443 'BEGIN {
  frac = ((now - ref) % cycle) / cycle
  if      (frac < 0.02 || frac > 0.98) phase = "New Moon"
  else if (frac < 0.23)                phase = "Waxing Crescent"
  else if (frac < 0.27)                phase = "First Quarter"
  else if (frac < 0.48)                phase = "Waxing Gibbous"
  else if (frac < 0.52)                phase = "Full Moon"
  else if (frac < 0.73)                phase = "Waning Gibbous"
  else if (frac < 0.77)                phase = "Last Quarter"
  else                                 phase = "Waning Crescent"
  print phase
}')

# Append the weather and moon data to the temp file
{
  echo "Airport: $AIRPORT"
  echo "Moon: $MOON_PHASE"
  echo ""
  echo "--- METAR ---"
  echo "$FORMATTED_METAR"
  echo ""
  echo "--- TAF ---"
  echo "$FORMATTED_TAF"
  echo ""
  echo "========================================"
  echo ""
} >> "$TEMP_FILE"

# 3. Print with 1-inch (72pt) left margin for 3-hole punch clearance
echo "Sending journal page to the default printer..."
lp -o page-left=72 -o page-top=54 -o page-right=54 -o page-bottom=54 "$TEMP_FILE"
