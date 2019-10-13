FROM docker/compose:1.24.0

RUN apk update && apk add curl && apk add net-tools && apk add bind-tools
#RUN apk add py-pip && apk add python-dev libffi-dev openssl-dev gcc libc-dev make
#RUN pip install docker-compose

RUN mkdir /neoload-cli

COPY ./entrypoint.sh /neoload-cli/
RUN chmod +x /neoload-cli/entrypoint.sh

COPY ./entrypoint-params.sh /neoload-cli/
RUN chmod +x /neoload-cli/entrypoint-params.sh

COPY ./nl_system_check.yaml /neoload-cli/

ENTRYPOINT ["/neoload-cli/entrypoint.sh"]
