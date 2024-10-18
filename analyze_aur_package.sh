#!/bin/bash

# Spinner functions

# Start the spinner
start_spinner(){
    local delay=0.1
    local spinstr='|/-\'
    while true; do
        for i in $(seq 0 3); do
            echo -ne "${spinstr:$i:1}" "\r"
            sleep $delay
        done
    done
}

# Stop the spinner
stop_spinner(){
    kill "$1" > /dev/null 2>&1
    echo -ne "\r"
}

# *** Configuration (Store API Key Securely) ***
if [[ ! -f ~/.gcp_api_key ]]; then
  echo "API key file not found. Please ensure ~/.gcp_api_key exists with appropriate permissions." >&2
  exit 1
fi
API_KEY=$(cat ~/.gcp_api_key)

# Function to retrieve PKGBUILD data using yay
get_pkgbuild_data() {
  local package_name="$1"

  # Capture the output and errors of the command separately
  local output
  output=$(yay -Gp "$package_name" 2>&1)

  # Check for specific errors and handle them appropriately
  if [[ "$output" == *"unable to find the following"* || "$output" == *"Unable to find the following packages: $package_name"* ]]; then
    exit 1
  fi

  echo "$output"
}

# Function to retrieve detailed package information using yay
get_package_info() {
  local package_name="$1"
  yay -Qi "$package_name" 2>/dev/null
}

# Function to retrieve AUR package details using the AUR RPC API
get_aur_details() {
  local package_name="$1"
  curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$package_name"
}

# Function to extract relevant information from PKGBUILD data
extract_pkgbuild_info() {
  local pkgbuild_data="$1"
  local dependencies source_urls integrity_checks author

  dependencies=$(grep -E 'depends|makedepends' <<< "$pkgbuild_data")
  source_urls=$(grep '^source=' <<< "$pkgbuild_data")
  integrity_checks=$(grep -E 'md5sums|sha256sums|b2sums' <<< "$pkgbuild_data")
  author=$(grep -i 'maintainer' <<< "$pkgbuild_data")

  echo "$dependencies"
  echo "$source_urls"
  echo "$integrity_checks"
  echo "$author"
}

# Construct the prompt for the API request
construct_prompt() {
  local pkgbuild_data="$1"
  local package_info="$2"
  local aur_details="$3"
  local dependencies="$4"
  local source_urls="$5"
  local integrity_checks="$6"
  local author="$7"

  cat <<EOF
Please review and provide insights on the security aspects of this Arch Linux package build information.

# PKGBUILD Data

${pkgbuild_data}

Note:
If this is an official repository package, it is generally presumed to be safe.
If this package is from the AUR, please consider additional scrutiny and take the package popularity and update date into account.

Specifically, please focus on for AUR packages:
1. Ensuring safe sources for downloading files.
2. Identifying potentially unsafe functions.
3. Highlighting any areas of the script that could lead to security concerns.
4. Verifying integrity of dependencies and source files.
5. Checking privileged operations and file permissions.
6. Ensuring patches are from trusted sources.

Additional context:
- Dependencies: ${dependencies}
- Source URLs: ${source_urls}
- Integrity Checks (e.g., sha256sums): ${integrity_checks}
- Maintainer/Author: ${author}

# Package Information

${package_info}

# AUR Package Details (if applicable)

${aur_details}
EOF
}

# Function to send API request and log response
send_api_request() {
  local prompt="$1"
  local api_url="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$API_KEY"

  local escaped_prompt
  escaped_prompt=$(echo "$prompt" | jq -Rs .)

  local json_data
  json_data=$(cat <<EOF
{
  "contents": [
    {
      "parts": [
        {
          "text": ${escaped_prompt}
        }
      ]
    }
  ]
}
EOF
)

  local response
  response=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST -H "Content-Type: application/json" -d "$json_data" "$api_url")

  local http_status
  http_status=$(echo "$response" | grep HTTP_STATUS_CODE | awk -F: '{print $2}' | tr -d ' \n')
  response=${response//HTTP_STATUS_CODE:*/}

  # Check the exit status of `curl` command directly and the HTTP status code
  if [[ $http_status -ne 200 ]]; then
    echo "Error making API request (HTTP status code: $http_status). Here is the response for debugging:" >&2
    echo "$response" >&2
    return 1
  fi

  echo "$response"
}

# Function to generate report
generate_report() {
  local package_name="$1"
  local pkgbuild_data="$2"
  local package_info="$3"
  local aur_details="$4"
  local ai_analysis="$5"

  local report_file="generated_report/${package_name}_report.md"
  {
    printf "# Security Analysis Report for %s\n\n" "$package_name"
    printf "## PKGBUILD Content\n\n"
    printf "\`\`\`sh\n%s\n\`\`\`\n\n" "$pkgbuild_data"
if [[ -n "$package_info" && "$package_info" != '{}' ]]; then
  printf "## Package Information\n\n"
  printf "\`\`\`sh\n%s\n\`\`\`\n\n" "$package_info"
fi
    if [[ "$aur_details" != '{}' ]]; then
      printf "## AUR Package Details\n\n"
      printf "\`\`\`sh\n%s\n\`\`\`\n\n" "$aur_details"
    fi
    printf "## AI Security Analysis\n\n%s\n" "$ai_analysis"
  } > "$report_file"

  echo "Report generated: ${report_file}"
}

# Main function to analyze the package build
analyze_pkgbuild() {
  local package_name="$1"

  # Get data from various sources
  local pkgbuild_data
  pkgbuild_data=$(get_pkgbuild_data "$package_name" 2>/dev/null) || {
    echo "Failed to retrieve PKGBUILD data for package: $package_name. Please check if the package name is correct and try again." >&2
    exit 1
  }
  local package_info
  package_info=$(get_package_info "$package_name" 2>/dev/null)

  local aur_details
  aur_details=$(get_aur_details "$package_name" 2>/dev/null)
  if [[ -z "$aur_details" || "$(echo "$aur_details" | jq '.resultcount')" -eq 0 ]]; then
    aur_details="{}"
  else
    aur_details=$(echo "$aur_details" | jq '.results[0]')
  fi

  # Extract information from PKGBUILD data
  IFS=$'\n' read -d '' -r dependencies source_urls integrity_checks author < <(extract_pkgbuild_info "$pkgbuild_data")

  # Construct prompt for AI
  local prompt
  prompt=$(construct_prompt "$pkgbuild_data" "$package_info" "$aur_details" "$dependencies" "$source_urls" "$integrity_checks" "$author")

  # Send API request and get AI response
local ai_response
if ! ai_response=$(send_api_request "$prompt"); then
  return 1
fi

  local ai_analysis
  if echo "$ai_response" | jq -e '.candidates | length > 0' > /dev/null; then
    ai_analysis=$(echo "$ai_response" | jq -r '.candidates[].content.parts[].text')
  else
    ai_analysis="No content generated due to safety reasons."
  fi

  # Generate the final report
  generate_report "$package_name" "$pkgbuild_data" "$package_info" "$aur_details" "$ai_analysis"
}

# Check for package name argument
if [ -z "$1" ]; then
  echo "Usage: $0 <package_name>"
  exit 1
fi


package_name="$1"

# Start the spinner and save its PID
start_spinner &
spinner_pid=$!

# Perform the analysis
analyze_pkgbuild "$package_name"

# Stop the spinner after the operation
stop_spinner "$spinner_pid"

echo "Operation completed."