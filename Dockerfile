FROM golang:1.13-alpine as builder

RUN mkdir /tmp/app
#
COPY . /tmp/app/
WORKDIR /tmp/app/

#RUN cd /tmp/app && \
RUN go mod vendor

RUN mkdir /tmp/building

COPY . /tmp/building/

RUN cd /tmp/building CP && \
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app ./

FROM golang:1.13-alpine

COPY  --from=builder /app ./
COPY ./cert ./cert


WORKDIR ./

CMD [ "./app", "--server_address", "0.0.0.0:8080"]