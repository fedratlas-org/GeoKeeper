package proto

import (
	"context"
	"encoding/json"
	"fmt"

	"google.golang.org/grpc"
	"google.golang.org/grpc/encoding"
)

// Register JSON Codec for gRPC wire format compatibility
type jsonCodec struct{}

func (jsonCodec) Name() string { return "proto" }

func (jsonCodec) Marshal(v interface{}) ([]byte, error) {
	return json.Marshal(v)
}

func (jsonCodec) Unmarshal(data []byte, v interface{}) error {
	return json.Unmarshal(data, v)
}

func init() {
	encoding.RegisterCodec(jsonCodec{})
}

// FeatureChangeRequest represents a feature change event
type FeatureChangeRequest struct {
	FeatureId    int64  `json:"feature_id,omitempty"`
	ActivityType string `json:"activity_type,omitempty"`
	FeatureData  []byte `json:"feature_data,omitempty"`
	Version      int32  `json:"version,omitempty"`
	CollectionId string `json:"collection_id,omitempty"`
}

func (x *FeatureChangeRequest) Reset()         { *x = FeatureChangeRequest{} }
func (x *FeatureChangeRequest) String() string { return fmt.Sprintf("FeatureChangeRequest{FeatureId: %d, ActivityType: %s}", x.FeatureId, x.ActivityType) }
func (*FeatureChangeRequest) ProtoMessage()    {}

// FeatureChangeResponse
type FeatureChangeResponse struct {
	Success bool   `json:"success,omitempty"`
	Error   string `json:"error,omitempty"`
}

func (x *FeatureChangeResponse) Reset()         { *x = FeatureChangeResponse{} }
func (x *FeatureChangeResponse) String() string { return fmt.Sprintf("FeatureChangeResponse{Success: %v, Error: %s}", x.Success, x.Error) }
func (*FeatureChangeResponse) ProtoMessage()    {}

// Peer
type Peer struct {
	ServerId    string  `json:"server_id,omitempty"`
	PublicKey   string  `json:"public_key,omitempty"`
	TrustScore  float64 `json:"trust_score,omitempty"`
	EndpointUrl string  `json:"endpoint_url,omitempty"`
	Status      string  `json:"status,omitempty"`
	LastSeen    int64   `json:"last_seen,omitempty"`
	CreatedAt   int64   `json:"created_at,omitempty"`
}

func (x *Peer) Reset()         { *x = Peer{} }
func (x *Peer) String() string { return x.ServerId }
func (*Peer) ProtoMessage()    {}

type AddPeerRequest struct {
	Peer *Peer `json:"peer,omitempty"`
}

func (x *AddPeerRequest) Reset()         { *x = AddPeerRequest{} }
func (x *AddPeerRequest) String() string { return "" }
func (*AddPeerRequest) ProtoMessage()    {}

type AddPeerResponse struct {
	Success bool   `json:"success,omitempty"`
	Error   string `json:"error,omitempty"`
}

func (x *AddPeerResponse) Reset()         { *x = AddPeerResponse{} }
func (x *AddPeerResponse) String() string { return "" }
func (*AddPeerResponse) ProtoMessage()    {}

type GetPeersRequest struct{}

func (x *GetPeersRequest) Reset()         { *x = GetPeersRequest{} }
func (x *GetPeersRequest) String() string { return "" }
func (*GetPeersRequest) ProtoMessage()    {}

type GetPeersResponse struct {
	Peers []*Peer `json:"peers,omitempty"`
}

func (x *GetPeersResponse) Reset()         { *x = GetPeersResponse{} }
func (x *GetPeersResponse) String() string { return "" }
func (*GetPeersResponse) ProtoMessage()    {}

type GetServerIDRequest struct{}

func (x *GetServerIDRequest) Reset()         { *x = GetServerIDRequest{} }
func (x *GetServerIDRequest) String() string { return "" }
func (*GetServerIDRequest) ProtoMessage()    {}

type GetServerIDResponse struct {
	ServerId string `json:"server_id,omitempty"`
}

func (x *GetServerIDResponse) Reset()         { *x = GetServerIDResponse{} }
func (x *GetServerIDResponse) String() string { return x.ServerId }
func (*GetServerIDResponse) ProtoMessage()    {}

type Manifest_EndpointConfig struct {
	InboxUrl    string `json:"inbox_url,omitempty"`
	OutboxUrl   string `json:"outbox_url,omitempty"`
	ManifestUrl string `json:"manifest_url,omitempty"`
}

type Manifest_DatasetInfo struct {
	Id           string `json:"id,omitempty"`
	Name         string `json:"name,omitempty"`
	Description  string `json:"description,omitempty"`
	FeatureCount int64  `json:"feature_count,omitempty"`
}

type Manifest struct {
	ProtocolVersion string                   `json:"protocol_version,omitempty"`
	ServerId        string                   `json:"server_id,omitempty"`
	Status          string                   `json:"status,omitempty"`
	PublicKey       string                   `json:"public_key,omitempty"`
	Endpoints       *Manifest_EndpointConfig `json:"endpoints,omitempty"`
	Datasets        []*Manifest_DatasetInfo  `json:"datasets,omitempty"`
}

func (x *Manifest) Reset()         { *x = Manifest{} }
func (x *Manifest) String() string { return x.ServerId }
func (*Manifest) ProtoMessage()    {}

type GetManifestRequest struct{}

func (x *GetManifestRequest) Reset()         { *x = GetManifestRequest{} }
func (x *GetManifestRequest) String() string { return "" }
func (*GetManifestRequest) ProtoMessage()    {}

// FedratlasServiceClient is the client API for FedratlasService service.
type FedratlasServiceClient interface {
	OnFeatureChange(ctx context.Context, in *FeatureChangeRequest, opts ...grpc.CallOption) (*FeatureChangeResponse, error)
	AddPeer(ctx context.Context, in *AddPeerRequest, opts ...grpc.CallOption) (*AddPeerResponse, error)
	GetPeers(ctx context.Context, in *GetPeersRequest, opts ...grpc.CallOption) (*GetPeersResponse, error)
	GetServerID(ctx context.Context, in *GetServerIDRequest, opts ...grpc.CallOption) (*GetServerIDResponse, error)
	GetManifest(ctx context.Context, in *GetManifestRequest, opts ...grpc.CallOption) (*Manifest, error)
}

type fedratlasServiceClient struct {
	cc grpc.ClientConnInterface
}

func NewFedratlasServiceClient(cc grpc.ClientConnInterface) FedratlasServiceClient {
	return &fedratlasServiceClient{cc}
}

func (c *fedratlasServiceClient) OnFeatureChange(ctx context.Context, in *FeatureChangeRequest, opts ...grpc.CallOption) (*FeatureChangeResponse, error) {
	out := new(FeatureChangeResponse)
	err := c.cc.Invoke(ctx, "/fedratlas.FedratlasService/OnFeatureChange", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *fedratlasServiceClient) AddPeer(ctx context.Context, in *AddPeerRequest, opts ...grpc.CallOption) (*AddPeerResponse, error) {
	out := new(AddPeerResponse)
	err := c.cc.Invoke(ctx, "/fedratlas.FedratlasService/AddPeer", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *fedratlasServiceClient) GetPeers(ctx context.Context, in *GetPeersRequest, opts ...grpc.CallOption) (*GetPeersResponse, error) {
	out := new(GetPeersResponse)
	err := c.cc.Invoke(ctx, "/fedratlas.FedratlasService/GetPeers", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *fedratlasServiceClient) GetServerID(ctx context.Context, in *GetServerIDRequest, opts ...grpc.CallOption) (*GetServerIDResponse, error) {
	out := new(GetServerIDResponse)
	err := c.cc.Invoke(ctx, "/fedratlas.FedratlasService/GetServerID", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *fedratlasServiceClient) GetManifest(ctx context.Context, in *GetManifestRequest, opts ...grpc.CallOption) (*Manifest, error) {
	out := new(Manifest)
	err := c.cc.Invoke(ctx, "/fedratlas.FedratlasService/GetManifest", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// FedratlasServiceServer is the server API for FedratlasService service.
type FedratlasServiceServer interface {
	OnFeatureChange(context.Context, *FeatureChangeRequest) (*FeatureChangeResponse, error)
	AddPeer(context.Context, *AddPeerRequest) (*AddPeerResponse, error)
	GetPeers(context.Context, *GetPeersRequest) (*GetPeersResponse, error)
	GetServerID(context.Context, *GetServerIDRequest) (*GetServerIDResponse, error)
	GetManifest(context.Context, *GetManifestRequest) (*Manifest, error)
}

func RegisterFedratlasServiceServer(s grpc.ServiceRegistrar, srv FedratlasServiceServer) {
	s.RegisterService(&FedratlasService_ServiceDesc, srv)
}

func _FedratlasService_OnFeatureChange_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(FeatureChangeRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(FedratlasServiceServer).OnFeatureChange(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/fedratlas.FedratlasService/OnFeatureChange",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(FedratlasServiceServer).OnFeatureChange(ctx, req.(*FeatureChangeRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _FedratlasService_AddPeer_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(AddPeerRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(FedratlasServiceServer).AddPeer(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/fedratlas.FedratlasService/AddPeer",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(FedratlasServiceServer).AddPeer(ctx, req.(*AddPeerRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _FedratlasService_GetPeers_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetPeersRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(FedratlasServiceServer).GetPeers(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/fedratlas.FedratlasService/GetPeers",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(FedratlasServiceServer).GetPeers(ctx, req.(*GetPeersRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _FedratlasService_GetServerID_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetServerIDRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(FedratlasServiceServer).GetServerID(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/fedratlas.FedratlasService/GetServerID",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(FedratlasServiceServer).GetServerID(ctx, req.(*GetServerIDRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _FedratlasService_GetManifest_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetManifestRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(FedratlasServiceServer).GetManifest(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/fedratlas.FedratlasService/GetManifest",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(FedratlasServiceServer).GetManifest(ctx, req.(*GetManifestRequest))
	}
	return interceptor(ctx, in, info, handler)
}

var FedratlasService_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "fedratlas.FedratlasService",
	HandlerType: (*FedratlasServiceServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "OnFeatureChange",
			Handler:    _FedratlasService_OnFeatureChange_Handler,
		},
		{
			MethodName: "AddPeer",
			Handler:    _FedratlasService_AddPeer_Handler,
		},
		{
			MethodName: "GetPeers",
			Handler:    _FedratlasService_GetPeers_Handler,
		},
		{
			MethodName: "GetServerID",
			Handler:    _FedratlasService_GetServerID_Handler,
		},
		{
			MethodName: "GetManifest",
			Handler:    _FedratlasService_GetManifest_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "fedratlas.proto",
}
