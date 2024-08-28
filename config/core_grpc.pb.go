// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.2.0
// - protoc             v5.27.3
// source: core.proto

package config

import (
	context "context"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.32.0 or later.
const _ = grpc.SupportPackageIsVersion7

// CoreServiceClient is the client API for CoreService service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type CoreServiceClient interface {
	ParseConfig(ctx context.Context, in *ParseConfigRequest, opts ...grpc.CallOption) (*ParseConfigResponse, error)
	GenerateFullConfig(ctx context.Context, in *GenerateConfigRequest, opts ...grpc.CallOption) (*GenerateConfigResponse, error)
}

type coreServiceClient struct {
	cc grpc.ClientConnInterface
}

func NewCoreServiceClient(cc grpc.ClientConnInterface) CoreServiceClient {
	return &coreServiceClient{cc}
}

func (c *coreServiceClient) ParseConfig(ctx context.Context, in *ParseConfigRequest, opts ...grpc.CallOption) (*ParseConfigResponse, error) {
	out := new(ParseConfigResponse)
	err := c.cc.Invoke(ctx, "/ConfigOptions.CoreService/ParseConfig", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *coreServiceClient) GenerateFullConfig(ctx context.Context, in *GenerateConfigRequest, opts ...grpc.CallOption) (*GenerateConfigResponse, error) {
	out := new(GenerateConfigResponse)
	err := c.cc.Invoke(ctx, "/ConfigOptions.CoreService/GenerateFullConfig", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// CoreServiceServer is the server API for CoreService service.
// All implementations must embed UnimplementedCoreServiceServer
// for forward compatibility
type CoreServiceServer interface {
	ParseConfig(context.Context, *ParseConfigRequest) (*ParseConfigResponse, error)
	GenerateFullConfig(context.Context, *GenerateConfigRequest) (*GenerateConfigResponse, error)
	mustEmbedUnimplementedCoreServiceServer()
}

// UnimplementedCoreServiceServer must be embedded to have forward compatible implementations.
type UnimplementedCoreServiceServer struct {
}

func (UnimplementedCoreServiceServer) ParseConfig(context.Context, *ParseConfigRequest) (*ParseConfigResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method ParseConfig not implemented")
}
func (UnimplementedCoreServiceServer) GenerateFullConfig(context.Context, *GenerateConfigRequest) (*GenerateConfigResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GenerateFullConfig not implemented")
}
func (UnimplementedCoreServiceServer) mustEmbedUnimplementedCoreServiceServer() {}

// UnsafeCoreServiceServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to CoreServiceServer will
// result in compilation errors.
type UnsafeCoreServiceServer interface {
	mustEmbedUnimplementedCoreServiceServer()
}

func RegisterCoreServiceServer(s grpc.ServiceRegistrar, srv CoreServiceServer) {
	s.RegisterService(&CoreService_ServiceDesc, srv)
}

func _CoreService_ParseConfig_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(ParseConfigRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(CoreServiceServer).ParseConfig(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/ConfigOptions.CoreService/ParseConfig",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(CoreServiceServer).ParseConfig(ctx, req.(*ParseConfigRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _CoreService_GenerateFullConfig_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GenerateConfigRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(CoreServiceServer).GenerateFullConfig(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/ConfigOptions.CoreService/GenerateFullConfig",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(CoreServiceServer).GenerateFullConfig(ctx, req.(*GenerateConfigRequest))
	}
	return interceptor(ctx, in, info, handler)
}

// CoreService_ServiceDesc is the grpc.ServiceDesc for CoreService service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var CoreService_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "ConfigOptions.CoreService",
	HandlerType: (*CoreServiceServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "ParseConfig",
			Handler:    _CoreService_ParseConfig_Handler,
		},
		{
			MethodName: "GenerateFullConfig",
			Handler:    _CoreService_GenerateFullConfig_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "core.proto",
}
