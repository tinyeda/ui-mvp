#+build !js
package app

import "core:encoding/json"
import "core:testing"

@(test)
workspace_panel_round_trip_test :: proc(t: ^testing.T) {
	workspace_loading = true
	panels_init()
	panel_add(.Schematic)
	panel_add(.Console)
	wanted_next_id := next_panel_id
	config_data, config_ok := workspace_config_data(context.temp_allocator)
	testing.expect(t, config_ok)
	panels_shutdown()

	testing.expect(t, workspace_restore_panels(config_data, false))
	testing.expect_value(t, len(panels), 4)
	testing.expect_value(t, panels[0].id, u64(1))
	testing.expect_value(t, panels[0].kind, Panel_Kind.Welcome)
	testing.expect_value(t, panels[2].kind, Panel_Kind.Schematic)
	testing.expect_value(t, panels[3].kind, Panel_Kind.Console)
	testing.expect_value(t, next_panel_id, wanted_next_id)
	testing.expect(t, !panels[0].dock_once)
	panels_shutdown()

	partial_string: string = `{"version":1}`
	partial := transmute([]byte)partial_string
	partial_config: Workspace_Config
	testing.expect(t, json.unmarshal(partial, &partial_config, allocator = context.temp_allocator) == nil)
	testing.expect(t, !workspace_restore_panels(partial, false))
	invalid_id_string: string = `{
		"format":"tinyeda-workspace",
		"version":1,
		"next_panel_id":1,
		"panel_count":1,
		"panels":[{"id":-1,"kind":"welcome"}]
	}`
	invalid_id := transmute([]byte)invalid_id_string
	invalid_id_config: Workspace_Config
	testing.expect(t, json.unmarshal(invalid_id, &invalid_id_config, allocator = context.temp_allocator) == nil)
	testing.expect(t, !workspace_restore_panels(invalid_id, false))
	workspace_loading = false
}

@(test)
text_contents_are_editable_test :: proc(t: ^testing.T) {
	testing.expect(t, text_contents_are_editable(nil))
	testing.expect(t, text_contents_are_editable([]byte{'a', '\n', 'b'}))
	testing.expect(t, !text_contents_are_editable([]byte{'a', 0, 'b'}))
}
