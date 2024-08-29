.ONESHELL:
PRODUCT_NAME=libcore
BASENAME=$(PRODUCT_NAME)
BINDIR=bin
LIBNAME=$(PRODUCT_NAME)
CLINAME=HiddifyCli

BRANCH=$(shell git branch --show-current)
VERSION=$(shell git describe --tags || echo "unknown version")

OS := $(shell uname -s)
ifeq ($(OS),Windows_NT)
	Not available for Windows! use bash in WSL
endif

TAGS=with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc
IOS_ADD_TAGS=with_dhcp,with_low_memory,with_conntrack
GOBUILDLIB=CGO_ENABLED=1 go build -trimpath -tags $(TAGS) -ldflags="-w -s" -buildmode=c-shared
GOBUILDSRV=CGO_ENABLED=1 go build -ldflags "-s -w" -trimpath -tags $(TAGS)

GO_VERSION := 1.22.5
GO_TARFILE := go$(GO_VERSION).tar.gz

ifeq ($(OS), Linux)
    OS_ARCH := $(shell uname -m)
    ifeq ($(OS_ARCH), x86_64)
        GO_TARFILE := go$(GO_VERSION).linux-amd64.tar.gz
    else
        $(error Unsupported architecture: $(OS_ARCH))
    endif
else ifeq ($(OS), Darwin)
    OS_ARCH := $(shell uname -m)
    ifeq ($(OS_ARCH), x86_64)
        GO_TARFILE := go$(GO_VERSION).darwin-amd64.tar.gz
    else ifeq ($(OS_ARCH), arm64)
        GO_TARFILE := go$(GO_VERSION).darwin-arm64.tar.gz
    else
        $(error Unsupported architecture: $(OS_ARCH))
    endif
else
    $(error Unsupported operating system: $(OS))
endif

GO_DOWNLOAD_URL := https://go.dev/dl/$(GO_TARFILE)
GO_SDK_DIR := /usr/local
GO_SDK_ROOT := $(GO_SDK_DIR)/go
GO_SDK_BIN_ROOT := $(GO_SDK_ROOT)/bin
GO_SDK_BIN_EXEC := $(GO_SDK_BIN_ROOT)/go

go-sdk-check: 
	@command -v go > /dev/null 2>&1 || { \
		echo "Go is not installed. Installing..."; \
		$(MAKE) go-sdk-download; \
		$(MAKE) go-sdk-configure; \
	}

go-sdk-download:
	@echo "Downloading Go SDK $(GO_VERSION) at $(GO_DOWNLOAD_URL)"
	@curl -LO $(GO_DOWNLOAD_URL)
	@echo "Extracting Go SDK $(GO_VERSION) to $(GO_SDK_DIR)"
	@mkdir -p $(GO_SDK_DIR)
	@tar -C $(GO_SDK_DIR) -xvf $(GO_TARFILE)
	@echo "Go SDK $(GO_VERSION) installed successfully."
	@rm -rf $(GO_TARFILE)
	@echo "Cleaned up downloaded files."

go-sdk-configure:
	@echo "Configuring Go SDK $(GO_VERSION) ..."
	@if [ "$(OS)" = "Linux" ]; then \
		echo 'export PATH="$$PATH:$(GO_SDK_BIN_ROOT)"' >> ~/.profile; \
		echo "Please run 'source ~/.profile' to update your PATH."; \
	elif [ "$(OS)" = "Darwin" ]; then \
		echo 'export PATH="$$PATH:$(GO_SDK_BIN_ROOT)"' >> ~/.zshrc; \
		echo "Please run 'source ~/.zshrc' to update your PATH."; \
	else \
		echo "Unsupported operating system: $(OS)"; \
		exit 1; \
	fi
	@$(GO_SDK_BIN_EXEC) env -w GOPATH="$$HOME/go"
	@$(GO_SDK_BIN_EXEC) env -w GO111MODULE=on
	@$(GO_SDK_BIN_EXEC) env -w GOPROXY="https://goproxy.io,direct"

go-deps-install:
#	@command -v protoc-gen-go --help > /dev/null 2>&1 || { \
#		echo "protoc-gen-go is not installed. Installing..."; \
#		go install google.golang.org/protobuf/cmd/protoc-gen-go@latest; \
#	}
#	@command -v protoc-gen-go-grpc --help > /dev/null 2>&1 || { \
#		echo "protoc-gen-go-grpc is not installed. Installing..."; \
#		go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest; \
#	}
	@command -v gomobile > /dev/null 2>&1 || { \
		echo "gomobile is not installed. Installing..."; \
		go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.1; \
	}
	@command -v gobind > /dev/null 2>&1 || { \
		echo "gobind is not installed. Installing..."; \
		go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.1; \
	}

proto-generate:
	@echo protoc --go_out=config --go-grpc_out=config --proto_path=protos protos/*.proto

prepare-install: go-sdk-check go-deps-install proto-generate

headers: go-sdk-check
	go build -buildmode=c-archive -o $(BINDIR)/$(LIBNAME).h ./custom

android: prepare-install
	gomobile bind -v -androidapi=21 -javapkg=io.nekohasekai -libname=box -tags=$(TAGS) -trimpath -target=android -o $(BINDIR)/$(LIBNAME).aar github.com/sagernet/sing-box/experimental/libbox ./mobile

ios-full: prepare-install
	gomobile bind -v  -target ios,iossimulator,tvos,tvossimulator,macos -libname=box -tags=$(TAGS),$(IOS_ADD_TAGS) -trimpath -ldflags="-w -s" -o $(BINDIR)/$(PRODUCT_NAME).xcframework github.com/sagernet/sing-box/experimental/libbox ./mobile 
	mv $(BINDIR)/$(PRODUCT_NAME).xcframework $(BINDIR)/$(LIBNAME).xcframework 
	cp Libcore.podspec $(BINDIR)/$(LIBNAME).xcframework/

ios: prepare-install
	gomobile bind -v  -target ios -libname=box -tags=$(TAGS),$(IOS_ADD_TAGS) -trimpath -ldflags="-w -s" -o $(BINDIR)/Libcore.xcframework github.com/sagernet/sing-box/experimental/libbox ./mobile
	cp Info.plist $(BINDIR)/Libcore.xcframework/

webui:
	curl -L -o webui.zip  https://github.com/hiddify/Yacd-meta/archive/gh-pages.zip 
	unzip -d ./ -q webui.zip
	rm webui.zip
	rm -rf bin/webui
	mv Yacd-meta-gh-pages bin/webui

.PHONY: build
windows-amd64:
	curl http://localhost:18020/exit || echo "exited"
	env GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc $(GOBUILDLIB) -o $(BINDIR)/$(LIBNAME).dll ./custom
	go install -mod=readonly github.com/akavel/rsrc@latest ||echo "rsrc error in installation"
	go run ./cli tunnel exit
	cp $(BINDIR)/$(LIBNAME).dll ./$(LIBNAME).dll 
	$$(go env GOPATH)/bin/rsrc -ico ./assets/hiddify-cli.ico -o ./cli/bydll/cli.syso ||echo "rsrc error in syso"
	env GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc CGO_LDFLAGS="$(LIBNAME).dll" $(GOBUILDSRV) -o $(BINDIR)/$(CLINAME).exe ./cli/bydll
	rm ./$(LIBNAME).dll
	make webui

linux-amd64: go-sdk-check
	mkdir -p $(BINDIR)/lib
	env GOOS=linux GOARCH=amd64 $(GOBUILDLIB) -o $(BINDIR)/lib/$(LIBNAME).so ./custom
	mkdir lib
	cp $(BINDIR)/lib/$(LIBNAME).so ./lib/$(LIBNAME).so
	env GOOS=linux GOARCH=amd64  CGO_LDFLAGS="./lib/$(LIBNAME).so" $(GOBUILDSRV) -o $(BINDIR)/$(CLINAME) ./cli/bydll
	rm -rf ./lib
	chmod +x $(BINDIR)/$(CLINAME)
	make webui

linux-custom: go-sdk-check
	mkdir -p $(BINDIR)/
	#env GOARCH=mips $(GOBUILDSRV) -o $(BINDIR)/$(CLINAME) ./cli/
	go build -ldflags "-s -w" -trimpath -tags $(TAGS) -o $(BINDIR)/$(CLINAME) ./cli/
	chmod +x $(BINDIR)/$(CLINAME)
	make webui

macos-amd64: go-sdk-check
	env GOOS=darwin GOARCH=amd64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 go build -trimpath -tags $(TAGS),$(IOS_ADD_TAGS) -buildmode=c-shared -o $(BINDIR)/$(LIBNAME)-amd64.dylib ./custom
macos-arm64: go-sdk-check
	env GOOS=darwin GOARCH=arm64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 go build -trimpath -tags $(TAGS),$(IOS_ADD_TAGS) -buildmode=c-shared -o $(BINDIR)/$(LIBNAME)-arm64.dylib ./custom
	
macos-universal: macos-amd64 macos-arm64 
	lipo -create $(BINDIR)/$(LIBNAME)-amd64.dylib $(BINDIR)/$(LIBNAME)-arm64.dylib -output $(BINDIR)/$(LIBNAME).dylib
	cp $(BINDIR)/$(LIBNAME).dylib ./$(LIBNAME).dylib 
	env GOOS=darwin GOARCH=amd64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="bin/$(LIBNAME).dylib"  CGO_ENABLED=1 $(GOBUILDSRV)  -o $(BINDIR)/$(CLINAME) ./cli/bydll
	rm ./$(LIBNAME).dylib
	chmod +x $(BINDIR)/$(CLINAME)

build_protobuf: prepare-install
	protoc --go_out=. --go-grpc_out=. hiddifyrpc/hiddify.proto

clean:
	rm $(BINDIR)/*