#!/bin/bash

set -e

# Define Variables
PRODUCT_NAME="libcore"
BASENAME="$PRODUCT_NAME"
BINDIR="bin"
LIBNAME="$PRODUCT_NAME"
CLINAME="HiddifyCli"

BRANCH=$(git branch --show-current)
VERSION=$(git describe --tags || echo "unknown version")

OS=$(uname -s)
GO_VERSION="1.22.5"
GO_TARFILE="go$GO_VERSION.tar.gz"

TAGS="with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc"
IOS_ADD_TAGS="with_dhcp,with_low_memory,with_conntrack"

GO_DOWNLOAD_URL="https://go.dev/dl/$GO_TARFILE"
GO_INSTALL_DIR="$HOME/sdk"
GO_ROOT_DIR="$GO_INSTALL_DIR/go"
GO_PATH_DIR="$HOME/go"
GO_ROOT_BIN_DIR="$GO_ROOT_DIR/bin"
GO_PATH_BIN_DIR="$GO_PATH_DIR/bin"

# Function Definitions

go-sdk-check() {
    if ! command -v go > /dev/null 2>&1; then
        echo "Go is not installed. Installing..."
        go-sdk-download
    fi
}

go-prints() {
    echo "GO_DOWNLOAD_URL: $GO_DOWNLOAD_URL"
    echo "GO_INSTALL_DIR: $GO_INSTALL_DIR"
    echo "GO_ROOT_DIR: $GO_ROOT_DIR"
    echo "GO_PATH_DIR: $GO_PATH_DIR"
    echo "GO_ROOT_BIN_DIR: $GO_ROOT_BIN_DIR"
    echo "GO_PATH_BIN_DIR: $GO_PATH_BIN_DIR"
}

go-sdk-download() {
    echo "Downloading Go SDK $GO_VERSION from $GO_DOWNLOAD_URL"
    mkdir -p "$GO_INSTALL_DIR"
    curl -LO "$GO_DOWNLOAD_URL"
    echo "Extracting Go SDK $GO_VERSION to $GO_ROOT_DIR"
    tar -C "$GO_INSTALL_DIR" -xvf "$GO_TARFILE"
    echo "Go SDK $GO_VERSION installed successfully."
    rm -f "$GO_TARFILE"
}

go-deps-install() {
    # if ! command -v protoc-gen-go > /dev/null 2>&1; then
    #     echo "protoc-gen-go is not installed. Installing..."
    #     go install -v google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
    # fi
    # if ! command -v protoc-gen-go-grpc > /dev/null 2>&1; then
    #     echo "protoc-gen-go-grpc is not installed. Installing..."
    #     go install -v google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
    # fi
    if ! command -v gomobile > /dev/null 2>&1; then
        echo "gomobile is not installed. Installing..."
        go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.3
    fi
    if ! command -v gobind > /dev/null 2>&1; then
        echo "gobind is not installed. Installing..."
        go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.3
    fi
}

proto-generate() {
    echo "proto-generate: ignored"
    # protoc --go_out=config --go-grpc_out=config --proto_path=protos protos/*.proto
}

prepare-install() {
    go-sdk-check
    go-deps-install
    proto-generate
}

headers() {
    go-sdk-check
    go build -buildmode=c-archive -o "$BINDIR/$LIBNAME.h" ./custom
}

android() {
    prepare-install
    gomobile bind -v -androidapi=21 -javapkg=io.nekohasekai -tags="$TAGS" -trimpath -target=android -o "$BINDIR/$LIBNAME.aar" github.com/sagernet/sing-box/experimental/libbox ./mobile
}

android-arm64() {
    prepare-install
    gomobile bind -v -androidapi=21 -javapkg=io.nekohasekai -tags="$TAGS" -trimpath -target=android/arm64 -o "$BINDIR/$LIBNAME.aar" github.com/sagernet/sing-box/experimental/libbox ./mobile
}

ios-full() {
    prepare-install
    gomobile bind -v -target ios,iossimulator,tvos,tvossimulator,macos -libname=box -tags="$TAGS,$IOS_ADD_TAGS" -trimpath -ldflags="-w -s" -o "$BINDIR/$PRODUCT_NAME.xcframework" github.com/sagernet/sing-box/experimental/libbox ./mobile
    mv "$BINDIR/$PRODUCT_NAME.xcframework" "$BINDIR/$LIBNAME.xcframework"
    cp Libcore.podspec "$BINDIR/$LIBNAME.xcframework/"
}

ios() {
    prepare-install
    gomobile bind -v -target ios -libname=box -tags="$TAGS,$IOS_ADD_TAGS" -trimpath -ldflags="-w -s" -o "$BINDIR/Libcore.xcframework" github.com/sagernet/sing-box/experimental/libbox ./mobile
    cp Info.plist "$BINDIR/Libcore.xcframework/"
}

webui() {
    curl -L -o webui.zip https://github.com/hiddify/Yacd-meta/archive/gh-pages.zip
    unzip -d ./ -q webui.zip
    rm webui.zip
    rm -rf bin/webui
    mv Yacd-meta-gh-pages bin/webui
}

windows-amd64() {
    env GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc go build -trimpath -tags "$TAGS" -ldflags="-s -w" -buildmode=c-shared -o "$BINDIR/$LIBNAME.dll" ./custom
	go install -mod=readonly github.com/akavel/rsrc@latest || echo "rsrc error in installation"
    go run ./cli tunnel exit
    cp "$BINDIR/$LIBNAME.dll" ./${LIBNAME}.dll
    $(go env GOPATH)/bin/rsrc -ico ./assets/hiddify-cli.ico -o ./cli/bydll/cli.syso || echo "rsrc error in syso"
    env GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc CGO_LDFLAGS="$LIBNAME.dll" go build -trimpath -tags "$TAGS" -ldflags="-s -w" -o "$BINDIR/$CLINAME.exe" ./cli/bydll
    rm ./${LIBNAME}.dll
    webui
}

linux-amd64() {
    go-sdk-check
    mkdir -p "$BINDIR/lib"
    env GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build -trimpath -tags "$TAGS" -ldflags="-s -w" -buildmode=c-shared -o "$BINDIR/lib/$LIBNAME.so" ./custom
    mkdir lib
    cp "$BINDIR/lib/$LIBNAME.so" ./lib/$LIBNAME.so
    env GOOS=linux GOARCH=amd64 CGO_ENABLED=1 CGO_LDFLAGS="./lib/$LIBNAME.so" go build -trimpath -tags "$TAGS" -ldflags="-s -w"  -o "$BINDIR/$CLINAME" ./cli/bydll
    rm -rf ./lib
    chmod +x "$BINDIR/$CLINAME"
    webui
}

linux-custom() {
    go-sdk-check
    mkdir -p "$BINDIR/"
    go build -trimpath -tags "$TAGS" -ldflags="-s -w" -o "$BINDIR/$CLINAME" ./cli/
    chmod +x "$BINDIR/$CLINAME"
    webui
}

macos-amd64() {
    go-sdk-check
    env GOOS=darwin GOARCH=amd64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 go build -trimpath -tags "$TAGS,$IOS_ADD_TAGS" -buildmode=c-shared -o "$BINDIR/$LIBNAME-amd64.dylib" ./custom
}

macos-arm64() {
    go-sdk-check
    env GOOS=darwin GOARCH=arm64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 go build -v -trimpath -tags "$TAGS,$IOS_ADD_TAGS" -buildmode=c-shared -o "$BINDIR/$LIBNAME-arm64.dylib" ./custom
}

macos-universal() {
    macos-amd64
    macos-arm64
    lipo -create "$BINDIR/$LIBNAME-amd64.dylib" "$BINDIR/$LIBNAME-arm64.dylib" -output "$BINDIR/$LIBNAME.dylib"
    cp "$BINDIR/$LIBNAME.dylib" ./"$LIBNAME.dylib"
    env GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="bin/$LIBNAME.dylib" go build -trimpath -tags "$TAGS" -ldflags="-s -w" -o "$BINDIR/$CLINAME" ./cli/bydll
    rm ./"$LIBNAME.dylib"
    chmod +x "$BINDIR/$CLINAME"
}

build-protobuf() {
    prepare-install
    protoc --go_out=. --go-grpc_out=. hiddifyrpc/hiddify.proto
}

clean() {
    rm -rf build "$BINDIR"/*
}

# Main entry point
case $1 in
    go-sdk-check)
        go-sdk-check
        ;;
    go-prints)
        go-prints
        ;;
    go-sdk-download)
        go-sdk-download
        ;;
    go-sdk-configure)
        go-sdk-configure
        ;;
    go-deps-install)
        go-deps-install
        ;;
    proto-generate)
        proto-generate
        ;;
    prepare-install)
        prepare-install
        ;;
    headers)
        headers
        ;;
    android)
        android
        ;;
    android-arm64)
        android-arm64
        ;;
    ios-full)
        ios-full
        ;;
    ios)
        ios
        ;;
    webui)
        webui
        ;;
    windows-amd64)
        windows-amd64
        ;;
    linux-amd64)
        linux-amd64
        ;;
    linux-custom)
        linux-custom
        ;;
    macos-amd64)
        macos-amd64
        ;;
    macos-arm64)
        macos-arm64
        ;;
    macos-universal)
        macos-universal
        ;;
    build-protobuf)
        build-protobuf
        ;;
    clean)
        clean
        ;;
    *)
        echo "Usage: $0 {go-sdk-check|go-prints|go-sdk-download|go-sdk-configure|go-deps-install|proto-generate|prepare-install|headers|android|ios-full|ios|webui|windows-amd64|linux-amd64|linux-custom|macos-amd64|macos-arm64|macos-universal|build-protobuf|clean}"
        exit 1
        ;;
esac