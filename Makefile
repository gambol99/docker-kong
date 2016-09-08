#
#
NAME=kong
AUTHOR ?= gambol99
REGISTRY ?= quay.io
VERSION ?= latest

.PHONY: build test

default: build

build:
	@echo "--> Builing the docker image: ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION}"
	docker build -t ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} .

push:
	@echo "--> Pushing the image to respository"
	docker push ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION}

clean:
	@echo "--> Performing a cleanup"
	docker rmi -f ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION}

test:
	@echo "--> Running the PostgreSQL database"
	@docker run -d -p 5432:5432 \
		--name=kong-postgres \
		-e PG_PASSWORD="password" \
		-e DB_NAME="kong" \
		sameersbn/postgresql
	@echo "--> Running the Kong service"
	@docker run -ti --rm --name=kong \
		--link=kong-postgres:database \
		--privileged=true \
		-v ${PWD}/tests:/etc/secrets \
		-p 8000:8000 -p 8443:8443 -p 8001:8001 \
		-e DEBUG=True \
		-e KONG_ACCESS_LOGS=on \
		-e KONG_ADMIN_CREDENTIALS_FILE=/etc/secrets/api.access \
		-e KONG_DATASTORE_CREDENTIALS_FILE=/etc/secrets/db.credentials \
		-e KONG_ADMIN_LISTEN=0.0.0.0:8001 \
		-e KONG_HTTP_LISTEN=0.0.0.0:8000 \
		-e KONG_HTTPS_LISTEN=0.0.0.0:8443 \
		-e KONG_DATABASE=postgres \
		-e KONG_PG_DATABASE=kong \
		-e KONG_PG_HOST=database \
		-e KONG_PG_PASS=password \
		-e KONG_PG_PORT=5432 \
		-e KONG_PG_USER=postgres \
		-e KONG_SSL_CERT=/etc/secrets/api.pem \
		-e KONG_SSL_CERT_KEY=/etc/secrets/api-key.pem \
		-e KONG_PROXY_PROTOCOL=off \
		${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} || true
	@echo "--> Deleting the Postgres service"
	@docker kill kong-postgres >/dev/null 2>&1
	@docker rm -v kong-postgres >/dev/null 2>&1
	@echo "--> Deleting the Kong service"
	@docker rm -v kong >/dev/null 2>&1

mockbin:
	@echo "--> Creating the Mockbin.org API"
	@curl -ik -X POST \
	  --url https://127.0.0.1:8001/apis/ \
		--user admin:password \
	  --data 'name=mockbin' \
	  --data 'upstream_url=http://mockbin.com/' \
	  --data 'request_host=mockbin.com'
	@echo "--> Calling the API"
	@curl -ik -X GET \
	  --url https://127.0.0.1:8443/ \
	  --header 'Host: mockbin.com'
