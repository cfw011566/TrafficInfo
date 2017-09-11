// Copyright © 2016 Alan A. A. Donovan & Brian W. Kernighan.
// License: https://creativecommons.org/licenses/by-nc-sa/4.0/

// See page 21.

// Server3 is an "echo" server that displays request parameters.
package main

import (
	"fmt"
	"log"
	"encoding/json"
	"net/http"
	"github.com/garyburd/redigo/redis"
)

type Keyword struct {
	Token	string
	Once	bool
	Region	string
	Pattern	string
}

const redisIPPort = "127.0.0.1:6379"
const fieldRegion = "Region"
const fieldOnce = "Once"
const fieldPattern = "Pattern"

func main() {
	http.HandleFunc("/token", handler)
	log.Fatal(http.ListenAndServe("localhost:8000", nil))
}

//!+handler
// handler echoes the HTTP request.
func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "%s %s %s\n", r.Method, r.URL, r.Proto)
	for k, v := range r.Header {
		fmt.Fprintf(w, "Header[%q] = %q\n", k, v)
	}
	fmt.Fprintf(w, "Host = %q\n", r.Host)
	fmt.Fprintf(w, "RemoteAddr = %q\n", r.RemoteAddr)
	if err := r.ParseForm(); err != nil {
		log.Print(err)
	}
	for k, v := range r.Form {
		fmt.Fprintf(w, "Form[%q] = %q\n", k, v)
	}

	defer r.Body.Close()
	var kw Keyword
	if err := json.NewDecoder(r.Body).Decode(&kw); err != nil {
		return
	}
	updateTokenKeyword(kw)
}

func updateTokenKeyword(kw Keyword) {
	var onceStr string

	conn, err := redis.Dial("tcp", redisIPPort)
	defer conn.Close()
	if err != nil {
		return
	}

	if kw.Once {
		onceStr = "1"
	} else {
		onceStr = "0"
	}

	key := "keyword:" + kw.Token
	conn.Do("HMSET", key, fieldOnce, onceStr, fieldRegion, kw.Region,
	    fieldPattern, kw.Pattern)
}

//!-handler
