package routes

import (
	"context"
	"github.com/gin-gonic/gin"
	pb "github.com/mymickey/go-micro-test/proto"
	"io/ioutil"
	"log"
	"net/http"
)


func InitRouters(hd pb.GreeterHandler) (ginEngine *gin.Engine) {
	ginRouter := gin.Default()
	ginRouter.POST("/", func(c *gin.Context) {
		jsonData, err := ioutil.ReadAll(c.Request.Body)
		log.Printf("json %s err %v",string(jsonData),err)
	})
	ginRouter.GET("/user/:name", func(ctx *gin.Context) {
		resp := pb.Response{}
		req := pb.Request{}
		name,_:=ctx.Params.Get("name")
		log.Printf("get user name is %s query value %v",name,ctx.Request.URL.Query())
		req.Name = name
		_ = hd.Hello(context.Background(),&req,&resp)
		ctx.JSON(http.StatusOK,&resp)
	})

	return ginRouter
}