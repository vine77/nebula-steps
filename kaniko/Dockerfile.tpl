FROM gcr.io/kaniko-project/executor:latest as base

FROM alpine:latest
ENV PATH "${PATH}:/kaniko"
ENV SSL_CERT_DIR=/kaniko/ssl/certs
ENV DOCKER_CONFIG /kaniko/.docker/
ENV DOCKER_CREDENTIAL_GCR_CONFIG /kaniko/.config/gcloud/docker_credential_gcr_config.json
RUN apk --no-cache add bash ca-certificates curl git jq openssh && update-ca-certificates
COPY --from=base /kaniko /kaniko
RUN ["docker-credential-gcr", "config", "--token-source=env"]
COPY ./step.sh /nebula/step.sh
CMD ["/bin/bash", "/nebula/step.sh"]
