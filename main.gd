extends Node2D

const WORLD_SIZE := Vector2(2400.0, 1400.0)
const WORLD_RECT := Rect2(Vector2.ZERO, WORLD_SIZE)
const CAMERA_SPEED := 520.0
const CAMERA_ZOOM_SPEED := 2.4
const MIN_ZOOM := 0.55
const MAX_ZOOM := 2.2

var observer_camera: Camera2D
var target_zoom := Vector2.ONE
var touch_points: Dictionary = {}
var pinch_distance := 0.0
var mouse_pan_active := false
var rng := RandomNumberGenerator.new()
var tobacco_fields: Array[Rect2] = [
    Rect2(380.0, 300.0, 270.0, 180.0),
    Rect2(760.0, 780.0, 330.0, 210.0),
    Rect2(1330.0, 380.0, 360.0, 230.0),
    Rect2(1700.0, 900.0, 300.0, 190.0)
]
var houses: Array[Vector2] = [
    Vector2(270.0, 260.0), Vector2(700.0, 580.0), Vector2(1160.0, 270.0),
    Vector2(1450.0, 760.0), Vector2(1880.0, 500.0), Vector2(2110.0, 1040.0)
]
var activity_points: Array[Vector2] = []

class Aldeano extends Node2D:
    const WALK_SPEED := 42.0
    const ARRIVAL_DISTANCE := 12.0
    const BODY_RADIUS := 7.0

    var activity_points: Array[Vector2] = []
    var target_position := Vector2.ZERO
    var rng := RandomNumberGenerator.new()
    var wait_remaining := 0.0

    func setup(points: Array[Vector2], seed_value: int) -> void:
        activity_points = points.duplicate()
        rng.seed = seed_value
        if activity_points.is_empty():
            return
        global_position = activity_points[rng.randi_range(0, activity_points.size() - 1)]
        _choose_next_activity()

    func _process(delta: float) -> void:
        if activity_points.is_empty():
            return
        if wait_remaining > 0.0:
            wait_remaining = maxf(wait_remaining - delta, 0.0)
            queue_redraw()
            return
        var distance_to_target := global_position.distance_to(target_position)
        if distance_to_target <= ARRIVAL_DISTANCE:
            wait_remaining = rng.randf_range(1.0, 3.5)
            _choose_next_activity()
            queue_redraw()
            return
        var direction := global_position.direction_to(target_position)
        global_position += direction * WALK_SPEED * delta
        queue_redraw()

    func _choose_next_activity() -> void:
        if activity_points.is_empty():
            return
        var next_index := rng.randi_range(0, activity_points.size() - 1)
        target_position = activity_points[next_index]

    func _draw() -> void:
        draw_circle(Vector2.ZERO, BODY_RADIUS, Color("#d8a06c"))
        draw_circle(Vector2(0.0, -2.0), 4.5, Color("#efd1a5"))
        draw_line(Vector2(-4.0, 6.0), Vector2(-4.0, 12.0), Color("#493d3a"), 2.0)
        draw_line(Vector2(4.0, 6.0), Vector2(4.0, 12.0), Color("#493d3a"), 2.0)

func _ready() -> void:
    rng.seed = 1426
    _create_observer_camera()
    _build_activity_points()
    _spawn_villagers(18)
    queue_redraw()

func _process(delta: float) -> void:
    _move_observer(delta)
    _zoom_observer(delta)
    observer_camera.zoom = observer_camera.zoom.lerp(target_zoom, 1.0 - exp(-10.0 * delta))

func _create_observer_camera() -> void:
    observer_camera = Camera2D.new()
    observer_camera.name = "CamaraObservacion"
    observer_camera.position = WORLD_SIZE * 0.5
    observer_camera.position_smoothing_enabled = true
    observer_camera.position_smoothing_speed = 7.0
    observer_camera.zoom = Vector2.ONE
    target_zoom = observer_camera.zoom
    observer_camera.limit_left = 0
    observer_camera.limit_top = 0
    observer_camera.limit_right = int(WORLD_SIZE.x)
    observer_camera.limit_bottom = int(WORLD_SIZE.y)
    observer_camera.enabled = true
    add_child(observer_camera)

func _move_observer(delta: float) -> void:
    var horizontal := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    var vertical := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    var direction := Vector2(horizontal, vertical).normalized()
    observer_camera.position += direction * CAMERA_SPEED * delta / observer_camera.zoom.x
    observer_camera.position.x = clampf(observer_camera.position.x, 0.0, WORLD_SIZE.x)
    observer_camera.position.y = clampf(observer_camera.position.y, 0.0, WORLD_SIZE.y)

func _zoom_observer(delta: float) -> void:
    var zoom_direction := float(Input.is_key_pressed(KEY_PAGEUP)) - float(Input.is_key_pressed(KEY_PAGEDOWN))
    if is_zero_approx(zoom_direction):
        return
    var next_zoom := clampf(target_zoom.x + zoom_direction * CAMERA_ZOOM_SPEED * delta, MIN_ZOOM, MAX_ZOOM)
    target_zoom = Vector2(next_zoom, next_zoom)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_pan_active = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(target_zoom.x + 0.12)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(target_zoom.x - 0.12)
    elif event is InputEventMouseMotion and mouse_pan_active:
        _pan_observer(event.relative)
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position
            if touch_points.size() == 2:
                pinch_distance = _get_pinch_distance()
        else:
            touch_points.erase(event.index)
            pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        if not touch_points.has(event.index):
            return
        touch_points[event.index] = event.position
        if touch_points.size() == 1:
            _pan_observer(event.relative)
            return
        if touch_points.size() != 2:
            return
        var next_pinch_distance := _get_pinch_distance()
        if is_zero_approx(pinch_distance):
            pinch_distance = next_pinch_distance
            return
        var zoom_ratio := next_pinch_distance / pinch_distance
        _set_zoom(target_zoom.x * zoom_ratio)
        pinch_distance = next_pinch_distance

func _pan_observer(screen_delta: Vector2) -> void:
    if screen_delta.is_zero_approx():
        return
    observer_camera.position -= screen_delta / observer_camera.zoom.x
    observer_camera.position.x = clampf(observer_camera.position.x, 0.0, WORLD_SIZE.x)
    observer_camera.position.y = clampf(observer_camera.position.y, 0.0, WORLD_SIZE.y)

func _get_pinch_distance() -> float:
    var points := touch_points.values()
    return points[0].distance_to(points[1])

func _set_zoom(value: float) -> void:
    var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
    target_zoom = Vector2(next_zoom, next_zoom)

func _build_activity_points() -> void:
    activity_points.clear()
    for field in tobacco_fields:
        for row in range(3):
            for column in range(4):
                activity_points.append(field.position + Vector2(35.0 + column * 55.0, 35.0 + row * 38.0))
    activity_points.append_array(houses)

func _spawn_villagers(count: int) -> void:
    for index in range(count):
        var villager := Aldeano.new()
        villager.name = "Aldeano_%02d" % index
        villager.setup(activity_points, rng.randi())
        add_child(villager)

func _draw() -> void:
    draw_rect(WORLD_RECT, Color("#6d9b67"))
    _draw_valley_floor()
    _draw_streams()
    _draw_fields()
    _draw_houses()
    _draw_title()

func _draw_valley_floor() -> void:
    var valley := PackedVector2Array([
        Vector2(120.0, 190.0), Vector2(480.0, 100.0), Vector2(990.0, 150.0),
        Vector2(1480.0, 90.0), Vector2(2200.0, 230.0), Vector2(2310.0, 1120.0),
        Vector2(1860.0, 1280.0), Vector2(1210.0, 1190.0), Vector2(620.0, 1300.0),
        Vector2(140.0, 1040.0)
    ])
    draw_colored_polygon(valley, Color("#a8bd78"))
    draw_polyline(valley, Color("#d0d892"), 5.0, true)

func _draw_streams() -> void:
    var riace := PackedVector2Array([
        Vector2(80.0, 0.0), Vector2(155.0, 250.0), Vector2(120.0, 510.0),
        Vector2(205.0, 790.0), Vector2(125.0, 1090.0), Vector2(220.0, WORLD_SIZE.y)
    ])
    var gorgone := PackedVector2Array([
        Vector2(2260.0, 0.0), Vector2(2160.0, 260.0), Vector2(2240.0, 560.0),
        Vector2(2140.0, 850.0), Vector2(2220.0, 1120.0), Vector2(2130.0, WORLD_SIZE.y)
    ])
    draw_polyline(riace, Color("#6bb6c2"), 34.0, true)
    draw_polyline(gorgone, Color("#6bb6c2"), 34.0, true)
    draw_polyline(riace, Color("#b1e0d7"), 3.0, true)
    draw_polyline(gorgone, Color("#b1e0d7"), 3.0, true)
    draw_string(ThemeDB.fallback_font, Vector2(55.0, 155.0), "Riace", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#1e5964"))
    draw_string(ThemeDB.fallback_font, Vector2(2190.0, 155.0), "Gorgone", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#1e5964"))

func _draw_fields() -> void:
    for field in tobacco_fields:
        draw_rect(field, Color("#718c4e"), true)
        draw_rect(field, Color("#d8c778"), false, 4.0)
        for row in range(3):
            var y := field.position.y + 34.0 + row * 38.0
            draw_line(Vector2(field.position.x + 18.0, y), Vector2(field.end.x - 18.0, y), Color("#526f42"), 3.0)

func _draw_houses() -> void:
    for house_position in houses:
        var footprint := Rect2(house_position - Vector2(34.0, 24.0), Vector2(68.0, 48.0))
        draw_rect(footprint, Color("#d6a46a"), true)
        draw_colored_polygon(PackedVector2Array([
            house_position + Vector2(-42.0, -24.0),
            house_position + Vector2(42.0, -24.0),
            house_position + Vector2(0.0, -52.0)
        ]), Color("#70473c"))
        draw_rect(Rect2(house_position + Vector2(-7.0, 4.0), Vector2(14.0, 20.0)), Color("#503b32"), true)

func _draw_title() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(68.0, 78.0), "COSPAIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#f5edc8"))
    draw_string(ThemeDB.fallback_font, Vector2(70.0, 108.0), "Valle libre | Observacion pasiva", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e2edc0"))
