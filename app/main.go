package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"context"
	"database/sql"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
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
		if err := dbPing(); err != nil {
			http.Error(w, "db ng: "+err.Error(), http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("db ok"))
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
	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func dbPing() error {
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")

	sec, err := loadDBSecret()
	if err != nil {
		return err
	}

	log.Printf("db secret loaded: username=%q dbname=%q", sec.Username, sec.DBName)

	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = sec.DBName
	}

	if sec.Username == "" {
		return fmt.Errorf("secret username is empty")
	}

	dsn := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=require",
		host, port, dbname, sec.Username, sec.Password,
	)

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	return db.PingContext(ctx)
}

type dbSecret struct {
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
	if s.Username == "" || s.Password == "" {
		return s, fmt.Errorf("secret missing username/password")
	}
	return s, nil
}
