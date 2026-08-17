return {
	version = 1,
	name = "Example Flux Show",
	songId = "",
	duration = 8,
	bpm = 128,
	events = {
		{ t = 0, target = "profile:1", action = "color", value = {180, 80, 255}, duration = 0.25 },
		{ t = 0, target = "profile:1", action = "level", value = 1, duration = 0.5 },
		{ t = 2, target = "profile:1", action = "pan", value = 45, duration = 1 },
		{ t = 4, target = "profile:1", action = "tilt", value = -25, duration = 1 },
		{ t = 7, target = "profile:1", action = "level", value = 0, duration = 1 },
	},
}
