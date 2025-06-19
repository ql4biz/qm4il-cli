#!/bin/bash 

[ -f "$HOME/.qm4ilrc" ] && source "$HOME/.qm4ilrc"

Qm4ilRequest () {
    if [ -z "$Qm4ilApiKey" ]; then
        echo "Missing API key. Please set 'Qm4ilApiKey' in ~/.qm4ilrc or export it."
        return 1
    fi

    local resource=$1
    if [ -z "$resource" ]; then
        echo "Path is required"
        return 1
    fi
    shift

    curl \
        --silent \
        --location "$Qm4ilApiEndpoint/$resource" \
        --header "X-Api-Key: $Qm4ilApiKey" \
        "$@" \
        | jq
}

Qm4ilInboxes () {
    Qm4ilRequest "inboxes" \
        "$@"
}

Qm4ilAccount () {
    Qm4ilRequest "me" \
        "$@"
}

Qm4ilMe () {
    Qm4ilAccount "$@"
}

Qm4ilCreateInbox () {
    local fqdn=${1:-""}
    local inboxName=${2:-""}
    
    local body=""
    if [ -n "$fqdn" ] || [ -n "$inboxName" ]; then
        # we want to include in the json only the kyes with non empty values
        if [ -n "$fqdn" ]; then
            body=$(jq -n --arg fqdn "$fqdn" '{fqdn: $fqdn}')
        fi
        if [ -n "$inboxName" ]; then
            body=$(jq -n --arg inboxName "$inboxName" '{inboxName: $inboxName}')
        fi
        if [ -n "$fqdn" ] && [ -n "$inboxName" ]; then
            body=$(jq -n --arg fqdn "$fqdn" --arg inboxName "$inboxName" '{fqdn: $fqdn, inboxName: $inboxName}')
        fi
        Qm4ilRequest "inboxes" \
            --request POST \
            --header 'Content-Type: application/json' \
            --data "$body"
    else
        Qm4ilRequest "inboxes" \
            --request POST
    fi  
}

Qm4ilGetInbox () {
    local inboxID=${1:-$Qm4ilDefaultInboxID}
    Qm4ilRequest "inboxes/$inboxID"
}

Qm4ilSendMessage () {
    Qm4ilRequest "emails" \
        --request POST \
        --header 'Content-Type: application/json' \
        --data "$@"
}

Qm4ilReceiveUnreadMessage () {
    local inboxID=${1:-$Qm4ilDefaultInboxID}
    if [ -z "$inboxID" ]; then
        echo "Missing inbox ID. Provide one or set defaultInboxID in ~/.qm4ilrc." >&2
        return 1
    fi

    local response
    response=$(Qm4ilRequest "emails/unread/$inboxID/latest" "$@" 2>/dev/null)

    # Normalize and check for 404
    if echo "$response" | tr -d '\000-\037' | jq -e '.statusCode == 404' > /dev/null 2>&1; then
        echo "$response" | tr -d '\000-\037' | jq >&2
        return 1
    fi

    # Success
    echo "$response" | tr -d '\000-\037' | jq
}

Qm4ilWaitForUnreadMessage () {
    local inboxID=${1:-$Qm4ilDefaultInboxID}
    if [ -z "$inboxID" ]; then
        echo "Missing inbox ID. Provide one or set defaultInboxID in ~/.qm4ilrc."
        return 1
    fi

    with_backoff Qm4ilReceiveUnreadMessage "$inboxID"
}

Qm4ilSendFortune () {

    which fortune > /dev/null
    if [ $? -ne 0 ]; then
        echo "Please install fortune"
        return 1
    fi

    local inboxID=${1:-$Qm4ilDefaultInboxID}
    if [ -z "$inboxID" ]; then
        echo "Missing inbox ID. Provide one or set defaultInboxID in ~/.qm4ilrc."
        return 1
    fi
    local from=${2:-"$Qm4ilDefaultInboxID@qm4il.com"}
    # local text=$(fortune)
    local text=$(fortune | sed 's/[\x00-\x1F]/ /g')
    # local subject=$(fortune -s -n 50)
    local subject=$(fortune -s -n 50 | sed 's/[\x00-\x1F]/ /g')

    local data=$(jq -n -c \
        --arg from "$from" \
        --arg inboxID "$inboxID" \
        --arg text "$text" \
        --arg subject "$subject"  '
        {
            from: $from,
            inboxID: $inboxID,
            text: $text,
            subject: $subject
        }'
    )

    Qm4ilSendMessage "$data"
}

Qm4ilFetchMessages () {
    local inboxID=${1:-$Qm4ilDefaultInboxID}
    if [ -z "$inboxID" ]; then
        echo "Missing inbox ID. Provide one or set defaultInboxID in ~/.qm4ilrc."
        return 1
    fi
    local limit=${2:-20}
    Qm4ilRequest "emails?inboxID=${inboxID}&limit=${limit}"
}

Qm4ilGetMessage () {
    local messageID=$1
    if [ -z "$messageID" ];then
        echo messageID is required
        return 1
    fi
    Qm4ilRequest "emails/$messageID"
}

Qm4ilReadMessage () {
    local messageID=$1
    if [ -z "$messageID" ];then
        echo messageID is required
        return 1
    fi
    Qm4ilRequest "emails/$messageID/read" \
        --request PATCH
}

Qm4ilMarkUnread () {
    local messageID=$1
    if [ -z "$messageID" ];then
        echo messageID is required
        return 1
    fi
    Qm4ilRequest "emails/$messageID/unread" \
        --request PATCH
}

Qm4ilInitConfig () {
    local rcfile="$HOME/.qm4ilrc"
    if [ -f "$rcfile" ]; then
        echo "$rcfile already exists. Edit it manually if needed."
        return
    fi

    echo "Initializing QM4IL config..."
    echo -n "Enter your QM4IL API key: "
    read Qm4ilApiKey
    echo -n "Enter your default inbox ID: "
    read Qm4ilDefaultInboxID

    cat > "$rcfile" <<EOF
# QM4IL CLI config
Qm4ilApiKey="$Qm4ilApiKey"
Qm4ilDefaultInboxID="$Qm4ilDefaultInboxID"
Qm4ilBackofAttempts=5
Qm4ilBackoffTimeout=1
Qm4ilApiEndpoint="https://api-staging.qm4il.com"  # Change to production when needed
EOF
    source "$rcfile"
    echo "Created $rcfile with provided values. You can update the endpoint when switching to production."
}

Qm4ilShowConfig () {
    local rcfile="$HOME/.qm4ilrc"
    if [ ! -f "$rcfile" ]; then
        echo "Config file not found at $rcfile"
        return 1
    fi
    echo -e "\nCurrent QM4IL configuration:\n"
    grep -v '^#' "$rcfile" # | sed 's/^/  /'
    echo -e "\n"
}

with_backoff() {
#   local max_attempts=${ATTEMPTS-5}
#   local timeout=${TIMEOUT-1}
  local max_attempts=${Qm4ilBackofAttempts-5}
  local timeout=${Qm4ilBackoffTimeout-1}
  local attempt=1

  while true; do
    "$@" && break || {
      if (( attempt == max_attempts )); then
        echo "Attempt $attempt failed and there are no more attempts left!" >&2
        return 1
      else
        echo "Attempt $attempt failed! Trying again in $timeout seconds..." >&2
        sleep $timeout
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
      fi
    }
  done
}
