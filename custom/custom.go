package main

/*
#include "stdint.h"
*/
import "C"
import (
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/log"

	"github.com/hiddify/hiddify-core/hiddifyrpc"
	"github.com/hiddify/hiddify-core/utils"
	"github.com/hiddify/hiddify-core/v2"
)

var (
	defaultOptionJson = ""
	defaultConfigJson = ""
	commandClient     *libbox.CommandClient
	commandHandler    = &commandHandlerImpl{}
	sps               = &libbox.SystemProxyStatus{Available: true, Enabled: false}
	defaultUpLink     int
	defaultDownLink   int
)

// export setupOnce
// func setupOnce(api unsafe.Pointer) {
// 	bridge.InitializeDartApi(api)
// }

// export setup
// func setup(baseDir *C.char, workingDir *C.char, tempDir *C.char, statusPort C.longlong, debug bool) (CErr *C.char) {
// 	return emptyOrErrorC(v2.Setup(C.GoString(baseDir), C.GoString(workingDir), C.GoString(tempDir), int64(statusPort), debug))
// }

//export startService
func startService() (CErr *C.char) {
	err := v2.Setup("/tmp/sbox/basheDir", "/tmp/sbox/workingDir", "/tmp/sbox/tempDir", 10110, false)
	if err != nil {
		return emptyOrErrorC(err)
	}
	allJson, err0 := getAllJson()
	if err0 != nil {
		return emptyOrErrorC(err0)
	}
	_, err = v2.Start(&hiddifyrpc.StartRequest{
		ConfigContent:          allJson,
		EnableOldCommandServer: true,
		DisableMemoryLimit:     false,
	})
	if err == nil {
		startCommandClient()
	}
	return emptyOrErrorC(err)
}

//export stopService
func stopService() (CErr *C.char) {
	_, err := v2.Stop()
	if err == nil {
		closeCommandServer()
	}
	return emptyOrErrorC(err)
}

//export setOptionJson
func setOptionJson(optionJson0 *C.char) {
	defaultOptionJson = C.GoString(optionJson0)
}

//export setConfigJson
func setConfigJson(configJson0 *C.char) {
	defaultConfigJson = C.GoString(configJson0)
}

func getAllJson() (string, error) {
	return utils.BuildConfig(defaultOptionJson, defaultConfigJson)
}

//export upLink
func upLink() int { return defaultUpLink }

//export downLink
func downLink() int { return defaultDownLink }

//export serviceStarted
func serviceStarted() bool { return v2.CoreState == hiddifyrpc.CoreState_STARTED }

func startCommandClient() (err error) {
	if commandClient == nil {
		commandClient = libbox.NewCommandClient(commandHandler, &libbox.CommandClientOptions{
			Command:        libbox.CommandStatus,
			StatusInterval: 1000000000,
		})
		err = commandClient.Connect()
	}
	return
}

func closeCommandServer() {
	if commandClient != nil {
		_ = commandClient.Disconnect()
		commandClient = nil
	}
}

func emptyOrErrorC(err error) *C.char {
	if err == nil {
		return C.CString("")
	}
	log.Error(err.Error())
	return C.CString(err.Error())
}

type commandHandlerImpl struct{}

func (c *commandHandlerImpl) Connected()          {}
func (c *commandHandlerImpl) Disconnected(string) {}
func (c *commandHandlerImpl) ClearLog()           {}
func (c *commandHandlerImpl) WriteLog(string)     {}
func (c *commandHandlerImpl) WriteStatus(message *libbox.StatusMessage) {
	defaultUpLink = int(message.Uplink)
	defaultDownLink = int(message.Downlink)
}
func (c *commandHandlerImpl) WriteGroups(libbox.OutboundGroupIterator)          {}
func (c *commandHandlerImpl) InitializeClashMode(libbox.StringIterator, string) {}
func (c *commandHandlerImpl) UpdateClashMode(string)                            {}
func (c *commandHandlerImpl) PostServiceClose()                                 {}
func (c *commandHandlerImpl) ServiceReload() (err error)                        { return }
func (c *commandHandlerImpl) GetSystemProxyStatus() *libbox.SystemProxyStatus   { return sps }
func (c *commandHandlerImpl) SetSystemProxyEnabled(bool) (err error)            { return }

func main() {}
