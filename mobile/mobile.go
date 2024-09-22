package mobile

import (
	"encoding/json"

	"github.com/hiddify/hiddify-core/config"
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/option"

	_ "github.com/sagernet/gomobile"
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
func Start() { serviceStarted = true }

//export Stop
func Stop() { serviceStarted = false }

//export ServiceStarted
func ServiceStarted() bool { return serviceStarted }

//export SetOptionJson
func SetOptionJson(optionJson string) { defaultOptionJson = optionJson }

//export SetConfigJson
func SetConfigJson(configJson string) { defaultConfigJson = configJson }

//export GetAllJson
func GetAllJson() (string, error) {
	return buildConfig(defaultOptionJson, defaultConfigJson)
}

//export IpLink
func UpLink() int { return upLink }

//export DownLink
func DownLink() int { return downLink }

func buildConfig(optionJson string, configJson string) (string, error) {
	var options option.Options
	err := options.UnmarshalJSON([]byte(configJson))
	if err != nil {
		return "", err
	}
	configOptions := &config.ConfigOptions{}
	err = json.Unmarshal([]byte(optionJson), configOptions)
	if err != nil {
		return "", nil
	}
	if configOptions.Warp.WireguardConfigStr != "" {
		err = json.Unmarshal([]byte(configOptions.Warp.WireguardConfigStr), &configOptions.Warp.WireguardConfig)
		if err != nil {
			return "", err
		}
	}
	if configOptions.Warp2.WireguardConfigStr != "" {
		err = json.Unmarshal([]byte(configOptions.Warp2.WireguardConfigStr), &configOptions.Warp2.WireguardConfig)
		if err != nil {
			return "", err
		}
	}
	return config.BuildConfigJson(*configOptions, options)
}

func StartCommandServer(boxService *libbox.BoxService) (err error) {
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
	if commandClient == nil {
		commandClient = libbox.NewCommandClient(commandHandler, &libbox.CommandClientOptions{
			Command:        libbox.CommandStatus,
			StatusInterval: 1000000000,
		})
		err = commandClient.Connect()
	}
	return
}

func CloseCommandServer() {
	if commandServer != nil {
		_ = commandServer.Close()
		commandServer = nil
	}
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
