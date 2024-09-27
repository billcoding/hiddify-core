package utils

import (
	"encoding/json"
	"github.com/hiddify/hiddify-core/config"
	"github.com/sagernet/sing-box/option"
)

func BuildConfig(optionJson string, configJson string) (string, error) {
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
