package  main

import (
	"context"
	"github.com/micro/go-micro"
	"github.com/micro/go-micro/registry"
	"github.com/micro/go-micro/registry/consul"
	"os"

	pb "github.com/mymickey/go-micro-test/proto"
	"log"
)

func main() {
	 reg:=consul.NewRegistry(func(options *registry.Options) {
		options.Addrs = []string{os.Getenv("MICRO_REGISTRY_ADDRESS")}
	})
	svc := micro.NewService(
		micro.Name("helloworld.client"),
		micro.Registry(reg),
		)
	hSvc := pb.NewGreeterService("helloworld",svc.Client())
	ctx,fn:=context.WithTimeout(context.Background(),20e9)
	defer fn()
	resp ,err:=hSvc.Hello(ctx,&pb.Request{Name:"123"})
	log.Println("resp %v err %v",resp,err)
}
