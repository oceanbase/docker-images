package main

import "testing"

func TestAdmissionRecoveryAndSurvivors(t *testing.T) {
	s := admission{}
	if s.update("1:100", true, true) || s.update("1:100", true, true) {
		t.Fatal("premature admission")
	}
	if !s.update("1:100", true, true) {
		t.Fatal("stable node not admitted")
	}
	if !s.update("1:100", true, false) {
		t.Fatal("survivor removed merely because one peer is offline")
	}
	if s.update("1:200", true, false) {
		t.Fatal("process restart inherited admission")
	}
	for i := 0; i < 3; i++ {
		s.update("1:200", true, true)
	}
	if s.update("1:200", false, true) {
		t.Fatal("unhealthy local node admitted")
	}
	if s.update("", true, true) {
		t.Fatal("missing process admitted")
	}
}
func TestAdmissionRequiresConsecutiveSuccesses(t *testing.T) {
	s := admission{}
	s.update("a", true, true)
	s.update("a", true, true)
	s.update("a", true, false)
	if s.update("a", true, true) || s.update("a", true, true) {
		t.Fatal("failed round did not reset stability window")
	}
	if !s.update("a", true, true) {
		t.Fatal("third consecutive round rejected")
	}
}
func TestPeerMatrixAndBootWindow(t *testing.T) {
	var x adminInfo
	x.Status = "success"
	x.Info.Backend.Online = 3
	for i := 0; i < 3; i++ {
		s := serverInfo{State: "online", Uptime: 30, Network: map[string]string{"a": "online", "b": "online", "c": "online"}}
		s.Drives = append(s.Drives, struct {
			State string `json:"state"`
			Local bool   `json:"local"`
		}{State: "ok"})
		x.Info.Servers = append(x.Info.Servers, s)
	}
	if !fullyConnected(x) {
		t.Fatal("healthy matrix rejected")
	}
	x.Info.Servers[1].Uptime = 2
	if fullyConnected(x) {
		t.Fatal("fresh boot accepted")
	}
	x.Info.Servers[1].Uptime = 30
	x.Info.Servers[1].Network["a"] = "offline"
	if fullyConnected(x) {
		t.Fatal("asymmetric peer connection accepted")
	}
}
