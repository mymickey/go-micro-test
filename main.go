package main

import (
	"context"
	"github.com/micro/go-micro"
	"log"
	rEtcd "github.com/micro/go-micro/registry/etcd"
	pb "github.com/mymickey/go-micro-test/proto"
	//"github.com/micro/cli"
)

type Greeter struct{}

func (g *Greeter) Hello(ctx context.Context, req *pb.Request, rsp *pb.Response) error {
	rsp.Greeting = "Hello " + req.Name
	return nil
}

func main() {
	service := micro.NewService(
		micro.Name("helloworld"),

	)
	err := service.Options().Registry.Init(rEtcd.Auth("root","123"))
	if err != nil {
		panic("etcd auth init err"+err.Error() )
	}
	service.Init()

	pb.RegisterGreeterHandler(service.Server(), new(Greeter))

	if err := service.Run(); err != nil {
		log.Fatal(err)
	}
}