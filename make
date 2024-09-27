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

case $OS in
    Linux)
        OS_ARCH=$(uname -m)
        if [ "$OS_ARCH" = "x86_64" ]; then
            GO_TARFILE="go$GO_VERSION.linux-amd64.tar.gz"
        else
            echo "Unsupported architecture: $OS_ARCH"
            exit 1
        fi
        ;;
    Darwin)
        OS_ARCH=$(uname -m)
        if [ "$OS_ARCH" = "x86_64" ]; then
            GO_TARFILE="go$GO_VERSION.darwin-amd64.tar.gz"
        elif [ "$OS_ARCH" = "arm64" ]; then
            GO_TARFILE="go$GO_VERSION.darwin-arm64.tar.gz"
        else
            echo "Unsupported architecture: $OS_ARCH"
            exit 1
        fi
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

GO_DOWNLOAD_URL="https://go.dev/dl/$GO_TARFILE"
GO_INSTALL_DIR="$HOME/sdk"
GO_ROOT_DIR="$GO_INSTALL_DIR/go"
GO_PATH_DIR="$HOME/go"
GO_ROOT_BIN_DIR="$GO_ROOT_DIR/bin"
GO_PATH_BIN_DIR="$GO_PATH_DIR/bin"
GO_EXEC_BIN_ENV="$GO_ROOT_BIN_DIR/go"
GO_EXEC_BIN="go"

# Function Definitions

go-sdk-check() {
    if ! command -v go > /dev/null 2>&1; then
        echo "Go is not installed. Installing..."
        go-sdk-download
        go-sdk-configure
    fi
}

go-prints() {
    echo "GO_DOWNLOAD_URL: $GO_DOWNLOAD_URL"
    echo "GO_INSTALL_DIR: $GO_INSTALL_DIR"
    echo "GO_ROOT_DIR: $GO_ROOT_DIR"
    echo "GO_PATH_DIR: $GO_PATH_DIR"
    echo "GO_ROOT_BIN_DIR: $GO_ROOT_BIN_DIR"
    echo "GO_PATH_BIN_DIR: $GO_PATH_BIN_DIR"
    echo "GO_EXEC_BIN_ENV: $GO_EXEC_BIN_ENV"
    echo "GO_EXEC_BIN: $GO_EXEC_BIN"
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

go-sdk-configure() {
    echo "Configuring Go SDK $GO_VERSION ..."
    PATH_ENTRY="export PATH=\"\$PATH:$GO_ROOT_BIN_DIR:$GO_PATH_BIN_DIR\""
    if [ "$OS" = "Linux" ]; then
        PROFILE_FILE="$HOME/.profile"
        if ! grep -Fxq "$PATH_ENTRY" "$PROFILE_FILE"; then
            echo "$PATH_ENTRY" >> "$PROFILE_FILE"
            echo "Please run 'source ~/.profile' to update your PATH."
        else
            echo "PATH entry already exists in $PROFILE_FILE."
        fi
    elif [ "$OS" = "Darwin" ]; then
        PROFILE_FILE="$HOME/.zshrc"
        if ! grep -Fxq "$PATH_ENTRY" "$PROFILE_FILE"; then
            echo "$PATH_ENTRY" >> "$PROFILE_FILE"
            echo "Please run 'source ~/.zshrc' to update your PATH."
        else
            echo "PATH entry already exists in $PROFILE_FILE."
        fi
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi
    GO_EXEC_BIN="$GO_EXEC_BIN_ENV"
    "$GO_EXEC_BIN" env -w GOPATH="$GO_PATH_DIR"
    "$GO_EXEC_BIN" env -w GO111MODULE=on
    "$GO_EXEC_BIN" env -w GOPROXY="https://goproxy.io,direct"
    export PATH="$PATH:$GO_ROOT_BIN_DIR:$GO_PATH_BIN_DIR"
}

go-deps-install() {
    # if ! command -v protoc-gen-go > /dev/null 2>&1; then
    #     echo "protoc-gen-go is not installed. Installing..."
    #     "$GO_EXEC_BIN" install -v google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
    # fi
    # if ! command -v protoc-gen-go-grpc > /dev/null 2>&1; then
    #     echo "protoc-gen-go-grpc is not installed. Installing..."
    #     "$GO_EXEC_BIN" install -v google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
    # fi
    if ! command -v gomobile > /dev/null 2>&1; then
        echo "gomobile is not installed. Installing..."
        "$GO_EXEC_BIN" install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.3
    fi
    if ! command -v gobind > /dev/null 2>&1; then
        echo "gobind is not installed. Installing..."
        "$GO_EXEC_BIN" install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.3
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
    "$GO_EXEC_BIN" build -buildmode=c-archive -o "$BINDIR/$LIBNAME.h" ./custom
}

android() {
    prepare-install
    gomobile bind -v -androidapi=21 -javapkg=io.nekohasekai -tags="$TAGS" -trimpath -target=android -o "$BINDIR/$LIBNAME.aar" github.com/sagernet/sing-box/experimental/libbox ./mobile
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
    curl http://localhost:18020/exit || echo "exited"
    GOBUILDLIB="CGO_ENABLED=1 \"$GO_EXEC_BIN\" build -trimpath -tags \"$TAGS\" -ldflags=\"-w -s\" -buildmode=c-shared"
    GOBUILDSRV="CGO_ENABLED=1 \"$GO_EXEC_BIN\" build -ldflags \"-s -w\" -trimpath -tags \"$TAGS\""
    env GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc "$GOBUILDLIB" -o "$BINDIR/$LIBNAME.dll" ./custom
    "$GO_EXEC_BIN" install -mod=readonly github.com/akavel/rsrc@latest || echo "rsrc error in installation"
    "$GO_EXEC_BIN" run ./cli tunnel exit
    cp "$BINDIR/$LIBNAME.dll" ./"$LIBNAME.dll"
    "$($GO_EXEC_BIN env GOPATH)/bin/rsrc" -ico ./assets/hiddify-cli.ico -o ./cli/bydll/cli.syso || echo "rsrc error in syso"
    env GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc CGO_LDFLAGS="$LIBNAME.dll" "$GOBUILDSRV" -o "$BINDIR/$CLINAME.exe" ./cli/bydll
    rm ./"$LIBNAME.dll"
    webui
}

linux-amd64() {
    go-sdk-check
    mkdir -p "$BINDIR/lib"
    GOBUILDLIB="CGO_ENABLED=1 \"$GO_EXEC_BIN\" build -trimpath -tags \"$TAGS\" -ldflags=\"-w -s\" -buildmode=c-shared"
    GOBUILDSRV="CGO_ENABLED=1 \"$GO_EXEC_BIN\" build -ldflags \"-s -w\" -trimpath -tags \"$TAGS\""
    env GOOS=linux GOARCH=amd64 "$GOBUILDLIB" -o "$BINDIR/lib/$LIBNAME.so" ./custom
    mkdir lib
    cp "$BINDIR/lib/$LIBNAME.so" ./lib/$LIBNAME.so
    env GOOS=linux GOARCH=amd64 CGO_LDFLAGS="./lib/$LIBNAME.so" "$GOBUILDSRV" -o "$BINDIR/$CLINAME" ./cli/bydll
    rm -rf ./lib
    chmod +x "$BINDIR/$CLINAME"
    webui
}

linux-custom() {
    go-sdk-check
    mkdir -p "$BINDIR/"
    "$GO_EXEC_BIN" build -ldflags "-s -w" -trimpath -tags "$TAGS" -o "$BINDIR/$CLINAME" ./cli/
    chmod +x "$BINDIR/$CLINAME"
    webui
}

macos-amd64() {
    go-sdk-check
    env GOOS=darwin GOARCH=amd64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 "$GO_EXEC_BIN" build -trimpath -tags "$TAGS,$IOS_ADD_TAGS" -buildmode=c-shared -o "$BINDIR/$LIBNAME-amd64.dylib" ./custom
}

macos-arm64() {
    go-sdk-check
    env GOOS=darwin GOARCH=arm64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_ENABLED=1 "$GO_EXEC_BIN" build -v -trimpath -tags "$TAGS,$IOS_ADD_TAGS" -buildmode=c-shared -o "$BINDIR/$LIBNAME-arm64.dylib" ./custom
}

macos-universal() {
    macos-amd64
    macos-arm64
    lipo -create "$BINDIR/$LIBNAME-amd64.dylib" "$BINDIR/$LIBNAME-arm64.dylib" -output "$BINDIR/$LIBNAME.dylib"
    cp "$BINDIR/$LIBNAME.dylib" ./"$LIBNAME.dylib"
    GOBUILDSRV="CGO_ENABLED=1 \"$GO_EXEC_BIN\" build -ldflags \"-s -w\" -trimpath -tags \"$TAGS\""
    env GOOS=darwin GOARCH=amd64 CGO_CFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="-mmacosx-version-min=10.11" CGO_LDFLAGS="bin/$LIBNAME.dylib" CGO_ENABLED=1 "$GOBUILDSRV" -o "$BINDIR/$CLINAME" ./cli/bydll
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