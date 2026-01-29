package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"context"
	"database/sql"
	"time"

	"log/slog"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func initLogger() *slog.Logger {
	h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})
	return slog.New(h)
}

func main() {

	logger := initLogger()
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = fmt.Fprintf(w, "hello from %s\n", os.Getenv("ENV"))
	})

	mux.HandleFunc("/db/health", func(w http.ResponseWriter, r *http.Request) {
		if err := dbPing(r.Context()); err != nil {
			slog.Warn("db_health_failed",
				"request_id", requestID(r.Context()),
				"amzn_trace_id", amznTraceID(r.Context()),
				"error", err.Error(),
			)
			http.Error(w, "db ng", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("db ok"))
	})

	mux.HandleFunc("/chaos/500", func(w http.ResponseWriter, r *http.Request) {
		if os.Getenv("ENABLE_CHAOS") != "1" {
			http.NotFound(w, r)
			return
		}

		slog.Warn("chaos_500",
			"request_id", requestID(r.Context()),
			"amzn_trace_id", amznTraceID(r.Context()),
		)

		http.Error(w, "chaos 500", http.StatusInternalServerError)
	})

	// rootはhelloに寄せておく（ALB確認が楽）
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.Redirect(w, r, "/hello", http.StatusFound)
	})

	addr := ":" + port
	slog.Info("listening", "addr", addr)

	if err := http.ListenAndServe(addr, withObservability(mux)); err != nil {
		slog.Error("server_exit", "error", err)
		os.Exit(1)
	}
}

func dbPing(ctx context.Context) error {
	sec, err := loadDBSecret()
	if err != nil {
		return err
	}

	slog.Info("db_secret_loaded",
		"request_id", requestID(ctx),
		"amzn_trace_id", amznTraceID(ctx),
		"host", sec.Host,
		"port", sec.Port,
		"username", sec.Username,
		"dbname", sec.DBName,
	)

	if sec.Host == "" {
		return fmt.Errorf("secret host is empty")
	}
	if sec.Port == 0 {
		return fmt.Errorf("secret port is empty")
	}
	if sec.DBName == "" {
		return fmt.Errorf("secret dbname is empty")
	}
	if sec.Username == "" {
		return fmt.Errorf("secret username is empty")
	}
	if sec.Password == "" {
		return fmt.Errorf("secret password is empty")
	}

	dsn := fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=require",
		sec.Host, sec.Port, sec.DBName, sec.Username, sec.Password,
	)

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	return db.PingContext(pingCtx)
}

type dbSecret struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Username string `json:"username"`
	Password string `json:"password"`
	DBName   string `json:"dbname"`
}

func loadDBSecret() (dbSecret, error) {
	var s dbSecret
	raw := os.Getenv("DB_SECRET_JSON")
	if raw == "" {
		return s, fmt.Errorf("DB_SECRET_JSON is empty")
	}
	if err := json.Unmarshal([]byte(raw), &s); err != nil {
		return s, fmt.Errorf("parse DB_SECRET_JSON: %w", err)
	}

	// 必須チェック（早めに落とす）
	if s.Host == "" || s.Port == 0 || s.DBName == "" || s.Username == "" || s.Password == "" {
		return s, fmt.Errorf("secret missing required fields")
	}
	return s, nil
}
