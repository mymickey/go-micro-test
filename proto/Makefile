.PHONY: greeter
greeter:
	protoc \
     -I . \
     -I ${GOPATH}/src/github.com/protocolbuffers/protobuf/src \
     -I ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate \
     --micro_out=. \
     --go_out=. \
     --validate_out="lang=go:." \
     ./greeter.proto
