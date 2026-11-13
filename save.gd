class_name Save

const PATH := "user://twofold.cfg"

static func load_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg

static func unlocked() -> int:
	return int(load_cfg().get_value("progress", "unlocked", 0))

static func unlock(level: int) -> void:
	var cfg := load_cfg()
	if level > int(cfg.get_value("progress", "unlocked", 0)):
		cfg.set_value("progress", "unlocked", level)
		cfg.save(PATH)

static func best(level: int) -> int:
	return int(load_cfg().get_value("best", str(level), 0))

static func record(level: int, moves: int) -> void:
	var cfg := load_cfg()
	var old := int(cfg.get_value("best", str(level), 0))
	if old == 0 or moves < old:
		cfg.set_value("best", str(level), moves)
		cfg.save(PATH)

static func daily_moves(day: int) -> int:
	var cfg := load_cfg()
	if int(cfg.get_value("daily", "day", 0)) != day:
		return 0
	return int(cfg.get_value("daily", "moves", 0))

static func record_daily(day: int, moves: int) -> void:
	var old := daily_moves(day)
	if old == 0 or moves < old:
		var cfg := load_cfg()
		cfg.set_value("daily", "day", day)
		cfg.set_value("daily", "moves", moves)
		cfg.save(PATH)
