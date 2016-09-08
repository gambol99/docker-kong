#!/bin/bash
#
[ -n "${DEBUG}" ] && {
  set -x;
  KONG_OPTS="--trace --vv";
}

annonce() {
  (2>/dev/null echo "[info] $@")
}

failed() {
  (2>/dev/null echo "[failed] $@")
  exit 1
}

NGINX_TMPL="/etc/kong/templates/nginx.lua"
KONG_DATASTORE_CREDENTIALS_FILE=${KONG_DATASTORE_CREDENTIALS_FILE:-""}
KONG_ADMIN_CREDENTIALS_FILE=${KONG_ADMIN_CREDENTIALS_FILE:-""}
KONG_PROXY_PROTOCOL=${KONG_PROXY_PROTOCOL:-"off"}

init_crendentials() {
  for file in ${KONG_DATASTORE_CREDENTIALS_FILE}; do
    if [[ ! -f "${file}" ]] || [[ ! -e "${file}" ]]; then
      failed "the crendentials file: ${file} does not exist or is not a file"
    fi
    annonce "Loading the crendentials file: ${file}"
    source ${file}
  done
}

init_nginx() {
  # step: create the admin authentication file
  [ -z "$KONG_SSL_CERT" ] && failed "you have not specified a TLS certificate via KONG_SSL_CERT"
  [ -z "$KONG_SSL_CERT_KEY"  ] && failed "you have not specified a TLS private key via KONG_SSL_CERT_KEY"

  mkdir -p /etc/nginx/conf
  touch /etc/nginx/conf/auth.conf
  if [[ -n "${KONG_ADMIN_CREDENTIALS_FILE}" ]]; then
    cat <<EOF > /etc/nginx/conf/auth.conf
auth_basic "forbidden access";
auth_basic_user_file ${KONG_ADMIN_CREDENTIALS_FILE};
EOF
  fi

  # step: are we using proxy protocol?
  if [[ ${KONG_PROXY_PROTOCOL} == "on" ]]; then
    annonce "Using the proxy protocol nginx template"
    NGINX_TMPL="/etc/kong/templates/nginx-proxy-protocol.lua"
  fi
}

init_database() {
  if [[ "$KONG_DATABASE" == "postgres" ]]; then
    # step: wait for the database to come up
    POSTGRES_UP=0
    annonce "Waiting for Postgres to startup "
    for ((i=0; i<10; i++)); do
      if timeout 1 bash -c "echo > /dev/tcp/${KONG_PG_HOST}/${KONG_PG_PORT}"  2>/dev/null; then
        POSTGRES_UP=1
        annonce "Postgres service available"
        break
      fi
      sleep 1
    done
    [ "$POSTGRES_UP" -ne 1 ] && failed "the database ${KONG_PG_HOST} did not come up"
    annonce "PostgreSQL service is running"
  fi
}

annonce "Generating Kong Service configuration"
init_crendentials
init_nginx
init_database

# step: jump into a shell if requested
[[ "$1" =~ ^(bash|sh)$ ]] && exec $1

exec kong start --nginx-conf=${NGINX_TMPL} ${KONG_OPTS}
