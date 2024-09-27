package mobile

import (
	"github.com/hiddify/hiddify-core/utils"
	_ "github.com/sagernet/gomobile"
	"github.com/sagernet/sing-box/experimental/libbox"
)

var (
	defaultOptionJson = ""
	defaultConfigJson = ""
	service           *libbox.BoxService
	commandServer     *libbox.CommandServer
	commandClient     *libbox.CommandClient
	commandHandler    = &commandHandlerImpl{}
	sps               = &libbox.SystemProxyStatus{Available: true, Enabled: false}
	upLink            int
	downLink          int
	serviceStarted    bool
)

//export Start
func Start(boxService *libbox.BoxService, connectCommandClient bool) {
	startCommandServer(boxService)
	if connectCommandClient {
		StartCommandClient()
	}
	serviceStarted = true
}

//export Stop
func Stop() { closeCommandServer(); closeCommandClient(); serviceStarted = false }

//export ServiceStarted
func ServiceStarted() bool { return serviceStarted }

//export SetOptionJson
func SetOptionJson(optionJson string) { defaultOptionJson = optionJson }

//export SetConfigJson
func SetConfigJson(configJson string) { defaultConfigJson = configJson }

//export GetAllJson
func GetAllJson() (string, error) {
	return utils.BuildConfig(defaultOptionJson, defaultConfigJson)
}

//export IpLink
func UpLink() int { return upLink }

//export DownLink
func DownLink() int { return downLink }

func startCommandServer(boxService *libbox.BoxService) (err error) {
	if boxService == nil {
		service = boxService
	}
	if commandServer == nil {
		commandServer = libbox.NewCommandServer(commandHandler, 10000)
		commandServer.SetService(boxService)
		if err = commandServer.Start(); err != nil {
			return
		}
	}
	return
}

//export StartCommandClient
func StartCommandClient() (err error) {
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
	if commandServer != nil {
		_ = commandServer.Close()
		commandServer = nil
	}
}

func closeCommandClient() {
	if commandClient != nil {
		_ = commandClient.Disconnect()
		commandClient = nil
	}
}

type commandHandlerImpl struct{}

func (c *commandHandlerImpl) Connected()          {}
func (c *commandHandlerImpl) Disconnected(string) {}
func (c *commandHandlerImpl) ClearLog()           {}
func (c *commandHandlerImpl) WriteLog(string)     {}
func (c *commandHandlerImpl) WriteStatus(message *libbox.StatusMessage) {
	upLink = int(message.Uplink)
	downLink = int(message.Downlink)
}
func (c *commandHandlerImpl) WriteGroups(libbox.OutboundGroupIterator)          {}
func (c *commandHandlerImpl) InitializeClashMode(libbox.StringIterator, string) {}
func (c *commandHandlerImpl) UpdateClashMode(string)                            {}
func (c *commandHandlerImpl) PostServiceClose()                                 {}
func (c *commandHandlerImpl) ServiceReload() (err error)                        { return }
func (c *commandHandlerImpl) GetSystemProxyStatus() *libbox.SystemProxyStatus   { return sps }
func (c *commandHandlerImpl) SetSystemProxyEnabled(bool) (err error)            { return }
