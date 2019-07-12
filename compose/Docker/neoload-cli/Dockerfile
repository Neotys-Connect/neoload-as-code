FROM docker:dind

RUN apk update && apk add curl && apk add net-tools && apk add bind-tools

RUN mkdir /neoload-cli

COPY ./entrypoint.sh /neoload-cli/
RUN chmod +x /neoload-cli/entrypoint.sh

COPY ./nl_system_check.yaml /neoload-cli/

ENTRYPOINT ["/neoload-cli/entrypoint.sh"]
