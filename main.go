package main

import (
	"context"
	"github.com/micro/cli"
	"github.com/micro/go-micro"
	//"github.com/micro/go-micro/transport"
	//"github.com/micro/go-micro/transport/grpc"
	"github.com/micro/go-micro/web"
	"github.com/mymickey/go-micro-test/routes"
	//rEtcd "github.com/micro/go-micro/registry/etcd"
	pb "github.com/mymickey/go-micro-test/proto"
	//"github.com/mymickey/go-micro-test/routes"
	"log"

	//"github.com/micro/cli"
)

type Greeter struct{}

func (g *Greeter) Hello(ctx context.Context, req *pb.Request, rsp *pb.Response) error {
	rsp.Greeting = "Hello " + req.Name
	return nil
}

func init()  {
	log.Printf("init func exec")
}

func main() {
	log.Printf("main start")
	hd := new(Greeter)
	log.Printf("NewRegistry done ")
	webServer:= web.NewService(
		web.Name("helloworld.web"),
		web.Address(":8080"),
		web.Handler(routes.InitRouters(hd)),
		)
	//grpcTrans := grpc.NewTransport(func(options *transport.Options) {
	//})
	service := micro.NewService(
		micro.Name("helloworld.svc"),
		micro.Address(":9902"),
		//micro.Transport(grpcTrans),
	)

	log.Printf("NewService done")


	service.Init(
		micro.Action(func(c *cli.Context) {
			if err := pb.RegisterGreeterHandler(service.Server(), hd);err != nil {
				panic(err)
			}
		}))

	log.Printf("server registry done")
	go webServer.Run()

	if err := service.Run(); err != nil {
		log.Fatal(err)
	}
	log.Printf("server run done")
}