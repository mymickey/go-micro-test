module github.com/mymickey/go-micro-test

go 1.15

require (
	github.com/gin-gonic/gin v1.6.3
	github.com/golang/protobuf v1.4.3
	github.com/hashicorp/consul/api v1.1.0
	github.com/json-iterator/go v1.1.9
	github.com/micro/cli v0.2.0
	github.com/micro/go-micro v1.6.0
	github.com/mitchellh/hashstructure v1.0.0
	github.com/nats-io/nats-server/v2 v2.1.9 // indirect
)

//replace github.com/micro/go-micro/ => github.com/micro/go-micro/v3 v3.5.0
//replace github.com/lucas-clemente/quic-go v0.13.1 => github.com/lucas-clemente/quic-go v0.14.0
