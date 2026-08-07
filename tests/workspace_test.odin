#+build !js
package tests

import "core:encoding/json"
import "core:testing"
import "../code/app"

@(test)
workspace_panel_round_trip_test :: proc(t: ^testing.T) {
	app.workspace_loading = true
	app.panels_init()
	app.panel_add(.SCHEMATIC)
	app.panel_add(.CONSOLE)
	wanted_next_id := app.next_panel_id
	config_data, config_ok := app.workspace_config_data(context.temp_allocator)
	testing.expect(t, config_ok)
	app.panels_shutdown()

	testing.expect(t, app.workspace_restore_panels(config_data, false))
	testing.expect_value(t, len(app.panels), 4)
	testing.expect_value(t, app.panels[0].id, u64(1))
	testing.expect_value(t, app.panels[0].kind, app.PanelKind.WELCOME)
	testing.expect_value(t, app.panels[2].kind, app.PanelKind.SCHEMATIC)
	testing.expect_value(t, app.panels[3].kind, app.PanelKind.CONSOLE)
	testing.expect_value(t, app.next_panel_id, wanted_next_id)
	testing.expect(t, !app.panels[0].dock_once)
	app.panels_shutdown()

	partial_string: string = `{"version":1}`
	partial := transmute([]byte)partial_string
	partial_config: app.WorkspaceConfig
	testing.expect(t, json.unmarshal(partial, &partial_config, allocator = context.temp_allocator) == nil)
	testing.expect(t, !app.workspace_restore_panels(partial, false))
	invalid_id_string: string = `{
		"format":"tinyeda-workspace",
		"version":1,
		"next_panel_id":1,
		"panel_count":1,
		"panels":[{"id":-1,"kind":"welcome"}]
	}`
	invalid_id := transmute([]byte)invalid_id_string
	invalid_id_config: app.WorkspaceConfig
	testing.expect(t, json.unmarshal(invalid_id, &invalid_id_config, allocator = context.temp_allocator) == nil)
	testing.expect(t, !app.workspace_restore_panels(invalid_id, false))
	app.workspace_loading = false
}

@(test)
text_contents_are_editable_test :: proc(t: ^testing.T) {
	testing.expect(t, app.text_contents_are_editable(nil))
	testing.expect(t, app.text_contents_are_editable([]byte{'a', '\n', 'b'}))
	testing.expect(t, !app.text_contents_are_editable([]byte{'a', 0, 'b'}))
}
