extends Node
## Language selection. Ukrainian is the primary language; ru and en follow.
## Strings come from locale/*.po via tr(); terminology is fixed in docs/GLOSSARY.md.

const SUPPORTED: PackedStringArray = ["uk", "ru", "en"]
const DEFAULT: String = "uk"


func _ready() -> void:
	set_language(str(Settings.get_value("ui", "language", DEFAULT)))


func set_language(code: String) -> void:
	TranslationServer.set_locale(code if code in SUPPORTED else DEFAULT)
