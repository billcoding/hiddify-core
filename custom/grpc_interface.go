package main

import "C"
import "github.com/hiddify/hiddify-core/v2"

// :ignored
func startCoreGrpcServer() (err error) {
	return v2.StartCoreGrpcServer(":51122")
}
