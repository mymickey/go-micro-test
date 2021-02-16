package routes

import (
	"context"
	"github.com/gin-gonic/gin"
	pb "github.com/mymickey/go-micro-test/proto"
	"net/http"
)

func InitRouters(hd pb.GreeterHandler) *gin.Engine {
	ginRouter := gin.Default()
	ginRouter.GET("/user/:name", func(ctx *gin.Context) {
		resp := pb.Response{}
		name,_:=ctx.Params.Get("name")
		_ = hd.Hello(context.Background(),&pb.Request{
			Name:           name      ,
		},&resp)
		ctx.JSON(http.StatusOK,&resp)
	})

	return ginRouter
}