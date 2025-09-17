extends Node
class_name SaveLoad

const SAVE_PATH := "user://taco_empire_save.json"

var _game_state_provider: Node = null

func register_provider(provider: Node) -> void:
    _game_state_provider = provider

func save_game() -> void:
    if _game_state_provider == null:
        push_warning("SaveLoad sin proveedor registrado")
        return
    var data := _game_state_provider.call("serialize_state")
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("No se pudo abrir archivo de guardado")
        return
    file.store_string(JSON.stringify(data, "\t"))
    file.close()

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("No se pudo leer archivo de guardado")
        return {}
    var text := file.get_as_text()
    file.close()
    var result := JSON.parse_string(text)
    if typeof(result) != TYPE_DICTIONARY:
        push_error("Formato de guardado inválido")
        return {}
    return result

func clear_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)
