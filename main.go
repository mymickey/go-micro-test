package main

import (
	"context"
	"crypto/tls"
	"github.com/micro/go-micro"
	"github.com/micro/go-micro/registry"
	rEtcd "github.com/micro/go-micro/registry/etcd"
	pb "github.com/mymickey/go-micro-test/proto"
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
	certFile, err := tls.LoadX509KeyPair("./cert/etcd.pem", "./cert/etcd-key.pem")
	if err != nil {
		log.Fatal(err)
	}
	reg := rEtcd.NewRegistry(func(op *registry.Options) {
		op.TLSConfig = &tls.Config{
			Certificates:[]tls.Certificate{certFile},
			ServerName:"Hello world",
			ClientAuth:tls.NoClientCert,
			InsecureSkipVerify:true,
		}
	})
	log.Printf("NewRegistry done ")
	service := micro.NewService(
		micro.Name("helloworld"),
		micro.Registry(reg),
	)
	log.Printf("NewService done ")
	service.Init(func(options *micro.Options) {
		micro.AfterStop(func() error {
			log.Printf("AfterStop ")
			return nil
		})
	})
	log.Printf("server init done")
	pb.RegisterGreeterHandler(service.Server(), new(Greeter))
	log.Printf("server registry done")
	if err := service.Run(); err != nil {
		log.Fatal(err)
	}
	log.Printf("server run done")
}