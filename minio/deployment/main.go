// Copyright 2026 OceanBase. Licensed under Apache-2.0; see LICENSE.
// Independent deployment helper. No MinIO source or Go libraries are linked.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

type serverInfo struct {
	State    string            `json:"state"`
	Endpoint string            `json:"endpoint"`
	Uptime   int64             `json:"uptime"`
	Network  map[string]string `json:"network"`
	Drives   []struct {
		State string `json:"state"`
		Local bool   `json:"local"`
	} `json:"drives"`
}
type adminInfo struct {
	Status string `json:"status"`
	Info   struct {
		Backend struct {
			Online  int `json:"onlineDisks"`
			Offline int `json:"offlineDisks"`
		} `json:"backend"`
		Servers []serverInfo `json:"servers"`
	} `json:"info"`
}

func fullyConnected(info adminInfo) bool {
	if info.Status != "success" || info.Info.Backend.Online != 3 || info.Info.Backend.Offline != 0 || len(info.Info.Servers) != 3 {
		return false
	}
	for _, s := range info.Info.Servers {
		if s.State != "online" || s.Uptime < 15 || len(s.Drives) != 1 || s.Drives[0].State != "ok" || len(s.Network) != 3 {
			return false
		}
		for _, state := range s.Network {
			if state != "online" {
				return false
			}
		}
	}
	return true
}

type admission struct {
	token     string
	successes int
	admitted  bool
}

func (s *admission) update(token string, localOK, strictOK bool) bool {
	if token == "" || token != s.token || !localOK {
		s.token = token
		s.successes = 0
		s.admitted = false
	}
	if token == "" || !localOK {
		return false
	}
	if s.admitted {
		return true
	}
	if strictOK {
		s.successes++
	} else {
		s.successes = 0
	}
	if s.successes >= 3 {
		s.admitted = true
	}
	return s.admitted
}
func processToken() string {
	entries, _ := os.ReadDir("/proc")
	for _, e := range entries {
		if _, err := strconv.Atoi(e.Name()); err != nil {
			continue
		}
		comm, err := os.ReadFile(filepath.Join("/proc", e.Name(), "comm"))
		if err != nil || strings.TrimSpace(string(comm)) != "minio" {
			continue
		}
		stat, err := os.ReadFile(filepath.Join("/proc", e.Name(), "stat"))
		if err != nil {
			continue
		}
		end := strings.LastIndex(string(stat), ")")
		if end < 0 {
			continue
		}
		fields := strings.Fields(string(stat[end+1:]))
		if len(fields) > 19 {
			return e.Name() + ":" + fields[19]
		}
	}
	return ""
}
func hostEnv(name, address string) (string, error) {
	u, err := url.Parse(address)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return "", errors.New("invalid endpoint")
	}
	u.User = url.UserPassword(os.Getenv("MINIO_ROOT_USER"), os.Getenv("MINIO_ROOT_PASSWORD"))
	return "MC_HOST_" + name + "=" + u.String(), nil
}
func mc(ctx context.Context, env []string, input []byte, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "/usr/bin/mc", args...)
	cmd.Env = append(os.Environ(), env...)
	cmd.Stdin = bytes.NewReader(input)
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		return nil, errors.New("mc request failed")
	}
	return output.Bytes(), nil
}
func healthy(ctx context.Context) bool {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, "http://127.0.0.1:9000/minio/health/cluster", nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	defer res.Body.Close()
	return res.StatusCode == 200
}
func strictCheck(ctx context.Context, env []string, key string) bool {
	raw, err := mc(ctx, env, nil, "--json", "admin", "info", "guard")
	if err != nil {
		return false
	}
	var info adminInfo
	if json.Unmarshal(raw, &info) != nil || !fullyConnected(info) {
		return false
	}
	if _, err = mc(ctx, env, nil, "mb", "--ignore-existing", "guard/deployment-guard-health"); err != nil {
		return false
	}
	payload := []byte("oceanbase independent deployment probe v1\n")
	if _, err = mc(ctx, env, payload, "pipe", "guard/deployment-guard-health/"+key); err != nil {
		return false
	}
	for i, s := range info.Info.Servers {
		peer, err := hostEnv(fmt.Sprintf("peer%d", i), "http://"+s.Endpoint)
		if err != nil {
			return false
		}
		data, err := mc(ctx, append(env, peer), nil, "cat", fmt.Sprintf("peer%d/deployment-guard-health/%s", i, key))
		if err != nil || !bytes.Equal(data, payload) {
			return false
		}
	}
	return true
}
func main() {
	if os.Getenv("MINIO_ROOT_USER") == "" || os.Getenv("MINIO_ROOT_PASSWORD") == "" {
		log.Fatal("credentials are required")
	}
	alias, err := hostEnv("guard", "http://127.0.0.1:9000")
	if err != nil {
		log.Fatal(err)
	}
	env := []string{alias, "MC_CONFIG_DIR=/tmp/deployment-guard-mc", "MC_UPDATE=off"}
	var ready atomic.Bool
	mux := http.NewServeMux()
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			w.WriteHeader(503)
			return
		}
		w.WriteHeader(200)
	})
	mux.HandleFunc("/live", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) })
	go func() {
		state := admission{}
		for {
			token := processToken()
			if token == "" || token != state.token {
				ready.Store(false)
				state.update(token, false, false)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			probeCtx, probeCancel := context.WithTimeout(ctx, 2*time.Second)
			localOK := healthy(probeCtx)
			probeCancel()
			if !localOK {
				ready.Store(false)
			}
			strictOK := false
			key := os.Getenv("HOSTNAME") + "-" + strings.ReplaceAll(token, ":", "-")
			if token != "" && localOK && (!state.admitted || token != state.token) {
				strictOK = strictCheck(ctx, env, key)
			}
			previous := ready.Load()
			// A restarted process must never inherit an earlier admission decision.
			current := state.update(token, localOK, strictOK)
			ready.Store(current)
			if previous != current {
				log.Printf("ready=%t process=%s successful_rounds=%d", current, token, state.successes)
			}
			if current && !previous {
				_, _ = mc(ctx, env, nil, "rm", "guard/deployment-guard-health/"+key)
			}
			cancel()
			time.Sleep(3 * time.Second)
		}
	}()
	log.Print("independent deployment guard listening on :8080; requires shared Pod process namespace")
	server := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 3 * time.Second}
	log.Fatal(server.ListenAndServe())
}
