package main

import "./app"

main :: proc() {
	if !app.Init() {
		return
	}
	defer app.Shutdown()

	for app.Running() {
		app.Frame()
	}
}
