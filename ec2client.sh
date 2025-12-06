#!/bin/sh

set -eu

AWS_PROFILE=""
REGION="us-east-2"
CONNECT_METHOD="ssm"
SSH_USER="ec2-user"
SSH_KEY_FILE=""
TAG_KEY=""
TAG_VALUE=""
SELECTED_ID=""

usage() {
  cat >&2 <<EOF
Usage: $0 [OPTIONS]

Optional:
  -t TAG_KEY        Tag key to filter instances
  -v TAG_VALUE      Tag value to filter instances
  -p PROFILE        AWS profile
  -r REGION         AWS region (default: us-east-2)
  -c METHOD         Connection method (ssh or ssm, default: ssm)
  -u USER           SSH user (default: ec2-user)
  -k KEYFILE        SSH private key file path

Note: If -t is specified, -v must also be specified (and vice versa)

Examples:
  $0
  $0 -t Environment -v prod
  $0 -t Environment -v staging -p myprofile -c ssh -k ~/.ssh/mykey.pem
  $0 -t Team -v backend -r us-west-2
EOF
  exit 1
}

error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

parse_options() {
  while getopts "p:t:v:r:c:u:k:h" opt; do
    case "$opt" in
    p) AWS_PROFILE="$OPTARG" ;;
    t) TAG_KEY="$OPTARG" ;;
    v) TAG_VALUE="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    c) CONNECT_METHOD="$OPTARG" ;;
    u) SSH_USER="$OPTARG" ;;
    k) SSH_KEY_FILE="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
    esac
  done
  shift $((OPTIND - 1))
}

validate_tag() {
  if [ -n "$TAG_KEY" ] || [ -n "$TAG_VALUE" ]; then
    if [ -z "$TAG_KEY" ] || [ -z "$TAG_VALUE" ]; then
      error_exit "Both tag key (-t) and tag value (-v) must be provided together"
    fi
  fi
}

validate_connect_method() {
  case "$CONNECT_METHOD" in
  ssh | ssm) ;;
  *) error_exit "Connection method must be: ssh or ssm" ;;
  esac
}

validate_ssh_key_file() {
  if [ -n "$SSH_KEY_FILE" ] && [ ! -f "$SSH_KEY_FILE" ]; then
    error_exit "SSH private key file not found: $SSH_KEY_FILE"
  fi
}

validate_parameters() {
  validate_tag
  validate_connect_method
  validate_ssh_key_file
}

check_dependencies() {
  for tool in aws session-manager-plugin ssh; do
    command -v "$tool" >/dev/null 2>&1 || error_exit "'$tool' is required but not found"
  done
}

build_aws_command() {
  if [ -n "$AWS_PROFILE" ]; then
    AWS_CMD="aws --profile $AWS_PROFILE --region $REGION"
  else
    AWS_CMD="aws --region $REGION"
  fi
}

query_instances() {
  if [ -n "$TAG_KEY" ]; then
    echo "Searching for EC2 instances with $TAG_KEY=$TAG_VALUE..." >&2

    $AWS_CMD ec2 describe-instances \
      --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
      "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], PublicIpAddress]' \
      --output text 2>/dev/null | sort -t"$(printf '\t')" -k2,2 || echo ""
  else
    echo "Searching for all running EC2 instances..." >&2

    $AWS_CMD ec2 describe-instances \
      --filters "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], PublicIpAddress]' \
      --output text 2>/dev/null | sort -t"$(printf '\t')" -k2,2 || echo ""
  fi
}

parse_instance_list() {
  instance_list="$1"
  echo "$instance_list" | awk '{if (NF > 0) print $1}'
}

count_instances() {
  instance_ids="$1"
  echo "$instance_ids" | grep -c . || echo "0"
}

display_instances() {
  instance_list="$1"

  echo "" >&2
  i=1
  echo "$instance_list" | while IFS="$(printf '\t')" read -r id name ip; do
    if [ -n "$id" ]; then
      display_name="${name:-$id}"
      display_ip="${ip:-no-public-ip}"
      echo "$i. $display_name ($id): $display_ip" >&2
      i=$((i + 1))
    fi
  done
  echo "" >&2
}

select_instance_number() {
  count="$1"

  while :; do
    printf "Select instance (1-$count): " >&2
    read -r selection </dev/tty || exit 1

    if [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -le "$count" ] 2>/dev/null; then
      echo "$selection"
      return 0
    fi

    echo "ERROR: Invalid selection" >&2
  done
}

get_instance_by_index() {
  instance_ids="$1"
  index="$2"
  echo "$instance_ids" | sed -n "${index}p"
}

select_instance() {
  instance_list="$1"
  instance_ids=$(parse_instance_list "$instance_list")
  count=$(count_instances "$instance_ids")

  if [ "$count" -eq 0 ]; then
    error_exit "No instances found"
  elif [ "$count" -eq 1 ]; then
    echo "Connecting to instance..." >&2
    SELECTED_ID=$(echo "$instance_ids" | head -n 1)
    return 0
  fi

  display_instances "$instance_list"
  selection=$(select_instance_number "$count")
  SELECTED_ID=$(get_instance_by_index "$instance_ids" "$selection")
}

get_instance_ip() {
  instance_id="$1"

  $AWS_CMD ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || echo ""
}

connect_ssh() {
  echo "Connecting to $SELECTED_ID via SSH..." >&2

  ip_address=$(get_instance_ip "$SELECTED_ID")
  if [ -z "$ip_address" ] || [ "$ip_address" = "None" ]; then
    error_exit "Instance does not have a public IP address for SSH connection"
  fi

  ssh_cmd="ssh -A $SSH_USER@$ip_address"
  if [ -n "$SSH_KEY_FILE" ]; then
    ssh_cmd="$ssh_cmd -i $SSH_KEY_FILE"
  fi

  echo "$ssh_cmd" >&2
  exec $ssh_cmd
}

connect_ssm() {
  echo "Connecting to $SELECTED_ID via SSM..." >&2

  $AWS_CMD ssm start-session \
    --target "$SELECTED_ID" \
    --document-name "AWS-StartInteractiveCommand" \
    --parameters '{"command":["cd; bash -l"]}'
}

connect() {
  case "$CONNECT_METHOD" in
  ssh) connect_ssh ;;
  ssm) connect_ssm ;;
  *) error_exit "Connection method must be: ssh or ssm" ;;
  esac
}

main() {
  parse_options "$@"
  validate_parameters
  check_dependencies
  build_aws_command

  instance_data=$(query_instances)
  if [ -z "$instance_data" ]; then
    error_exit "No instances found"
  fi

  select_instance "$instance_data"
  connect
}

main "$@"
