#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
ENV_EXAMPLE_FILE="${ENV_EXAMPLE_FILE:-.env.example}"
HTPASSWD_FILE="${HTPASSWD_FILE:-.htpasswd}"

SECRET_LENGTH="${SECRET_LENGTH:-32}"

generate_url_safe_secret() {
  local length="${1:-32}"
  local secret=""

  while [[ "${#secret}" -lt "${length}" ]]; do
    secret="${secret}$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9_-')"
  done

  printf '%s' "${secret:0:${length}}"
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Error: required command not found: ${command_name}" >&2
    exit 1
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"

  if grep -qE "^${key}=" "${file}"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "${file}"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

generate_htpasswd_apr1() {
  local username="$1"
  local password="$2"
  local output_file="$3"

  # Apache MD5 format. Supported by nginx auth_basic.
  local hash
  hash="$(openssl passwd -apr1 "${password}")"

  printf '%s:%s\n' "${username}" "${hash}" > "${output_file}"
  chmod 644 "${output_file}"
}

main() {
  require_command openssl
  require_command tr
  require_command sed
  require_command grep
  require_command awk

  if [[ "${SECRET_LENGTH}" -lt 24 ]]; then
    echo "Error: SECRET_LENGTH must be at least 24 characters." >&2
    exit 1
  fi

  if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${ENV_EXAMPLE_FILE}" ]]; then
      cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
      echo "Created ${ENV_FILE} from ${ENV_EXAMPLE_FILE}"
    else
      echo "Error: ${ENV_FILE} does not exist and ${ENV_EXAMPLE_FILE} was not found." >&2
      exit 1
    fi
  fi

  POSTGRES_PASSWORD="$(generate_url_safe_secret "${SECRET_LENGTH}")"
  AWS_ACCESS_KEY_ID="$(generate_url_safe_secret "${SECRET_LENGTH}")"
  AWS_SECRET_ACCESS_KEY="$(generate_url_safe_secret "${SECRET_LENGTH}")"
  NGINX_BASIC_AUTH_PASSWORD="$(generate_url_safe_secret "${SECRET_LENGTH}")"

  set_env_value "POSTGRES_PASSWORD" "${POSTGRES_PASSWORD}" "${ENV_FILE}"
  set_env_value "AWS_ACCESS_KEY_ID" "${AWS_ACCESS_KEY_ID}" "${ENV_FILE}"
  set_env_value "AWS_SECRET_ACCESS_KEY" "${AWS_SECRET_ACCESS_KEY}" "${ENV_FILE}"
  set_env_value "NGINX_BASIC_AUTH_PASSWORD" "${NGINX_BASIC_AUTH_PASSWORD}" "${ENV_FILE}"

  NGINX_BASIC_AUTH_USER="$(
    awk -F '=' '
        /^NGINX_BASIC_AUTH_USER=/ {
        value = substr($0, index($0, "=") + 1)
        }
        END {
        print value
        }
    ' "${ENV_FILE}"
    )"

  if [[ -z "${NGINX_BASIC_AUTH_USER}" ]]; then
    NGINX_BASIC_AUTH_USER="admin"
    set_env_value "NGINX_BASIC_AUTH_USER" "${NGINX_BASIC_AUTH_USER}" "${ENV_FILE}"
  fi

  generate_htpasswd_apr1 \
    "${NGINX_BASIC_AUTH_USER}" \
    "${NGINX_BASIC_AUTH_PASSWORD}" \
    "${HTPASSWD_FILE}"

  rm -f "${ENV_FILE}.bak"

  chmod 600 "${ENV_FILE}"

  echo
  echo "Secrets generated successfully."
  echo
  echo "Updated:"
  echo "  - ${ENV_FILE}"
  echo "  - ${HTPASSWD_FILE}"
  echo
  echo "Nginx basic auth credentials:"
  echo "  username: ${NGINX_BASIC_AUTH_USER}"
  echo "  password: ${NGINX_BASIC_AUTH_PASSWORD}"
  echo
  echo "Store the Nginx password somewhere safe. It is only shown once here."
}

main "$@"
