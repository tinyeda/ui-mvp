package main

import "./app"

main :: proc() {
	if !app.init() {
		return
	}
	defer app.shutdown()

	for app.is_running() {
		app.frame()
	}
}
