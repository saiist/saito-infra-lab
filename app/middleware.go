package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"time"
)

type ctxKey string

const (
	ctxKeyRequestID   ctxKey = "request_id"
	ctxKeyAmznTraceID ctxKey = "amzn_trace_id"
)

func newRequestID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func withObservability(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		reqID := r.Header.Get("X-Request-Id")
		if reqID == "" {
			reqID = newRequestID()
		}
		amznTraceID := r.Header.Get("X-Amzn-Trace-Id")

		// 返す（クライアント側調査にも使える）
		w.Header().Set("X-Request-Id", reqID)
		if amznTraceID != "" {
			w.Header().Set("X-Amzn-Trace-Id", amznTraceID)
		}

		ctx := context.WithValue(r.Context(), ctxKeyRequestID, reqID)
		ctx = context.WithValue(ctx, ctxKeyAmznTraceID, amznTraceID)
		r = r.WithContext(ctx)

		sw := &statusWriter{ResponseWriter: w, status: 200}
		next.ServeHTTP(sw, r)

		slog.Info("http_request",
			"request_id", reqID,
			"amzn_trace_id", amznTraceID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", sw.status,
			"latency_ms", time.Since(start).Milliseconds(),
			"user_agent", r.UserAgent(),
		)
	})
}

func requestID(ctx context.Context) string {
	v, _ := ctx.Value(ctxKeyRequestID).(string)
	return v
}
func amznTraceID(ctx context.Context) string {
	v, _ := ctx.Value(ctxKeyAmznTraceID).(string)
	return v
}
