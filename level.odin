package snake

import "core:math/rand"
import "base:runtime"
import rl "vendor:raylib"

TileRef :: struct {
    index: int,
    valid: bool,
}

Level :: struct {
    tile_size: f32,
    width: int,
    height: int,
    tiles: [dynamic]TileType,
    tile_refs: [dynamic]TileRef,
    score: int, 
    snake: Snake,
}

level_init :: proc(
    tile_size: f32,
    width: int,
    height: int,
    snake_x: int,
    snake_y: int,
    snake_speed: f32,
    snake_length: int,
    snake_orientation: Orientation,
    allocator := context.allocator,
    loc := #caller_location
) -> (level: Level, err: runtime.Allocator_Error) {
    level.tile_size = tile_size
    level.width = width
    level.height = height

    body_path := make(
        [dynamic]Direction,
        len = snake_length, 
        allocator = allocator,
        loc = loc) or_return
    defer if err != nil do delete(body_path)

    for i in 0..<snake_length {
        body_path[i] = .Straight
    }

    level.snake = {
        head_tile = {snake_x, snake_y},
        speed = snake_speed,
        orientation = snake_orientation,
        body_path = body_path,
        head_rotation_goal = .Straight,
        orientation_request = nil,
        progress = 0.5,
        head_rotation = 0,
        need_to_grow = 0,
        head_radius = 0.3,
        tail_radius = 0.15,
        length = f32(snake_length),
        body_color = rl.GREEN,
        outline_color = rl.DARKGREEN,
        outline_thickness = 0.1,
        user_data = nil,
    }

    level.tiles = make(
        [dynamic]TileType,
        len = width * height,
        allocator = allocator,
        loc = loc) or_return
    defer if err != nil do delete(level.tiles)

    level.tile_refs = make(
        [dynamic]TileRef,
        len = 0,
        cap = width * height,
        allocator = allocator,
        loc = loc) or_return

    return
}

level_destroy :: proc(level: Level) {
    delete(level.tiles)
    delete(level.tile_refs)
    delete(level.snake.body_path)
}

LevelUpdateResult :: enum {
    Success,
    GameLose,
    GameWin,
}

level_update :: proc(level: ^Level, dt: f32) -> (lur: LevelUpdateResult) {
    level.snake.user_data = level
    sur := snake_update(&level.snake, dt, level_tile_at, level_eat_apple)
    switch sur {
    case .Success:
        lur = .Success
    case .GameOverWall:
        lur = .GameLose
    case .GameOverSelf:
        if len(level.snake.body_path) == level.width * level.height {
            lur = .GameWin
        } else {
            lur = .GameLose
        }
    }
    return
}

@(private)
level_eat_apple :: proc(x, y: int, user_data: rawptr) {
    level := (^Level)(user_data)
    level.tiles[x + y * level.width] = .Empty
    level.score += 1
    level_add_new_random_apple(level)
}

@(private)
level_tile_at :: proc(x, y: int, user_data: rawptr) -> TileType {
    level := (^Level)(user_data)
    if x < 0 || y < 0 || x >= level.width || y >= level.height {
        return .Wall
    }
    return level.tiles[x + y * level.width]
}

level_add_new_random_apple :: proc(level: ^Level) -> bool {
    clear(&level.tile_refs)
    for i in 0..<level.width*level.height {
        append(&level.tile_refs, TileRef{
            index = i,
            valid = true,
        })
    }

    head_idx := level.snake.head_tile.x + level.snake.head_tile.y * level.width
    level.tile_refs[head_idx].valid = false
    
    orientation := opposite_orientation(level.snake.orientation)
    tile := tile_move(level.snake.head_tile, opposite_orientation(level.snake.orientation))
    for dir in level.snake.body_path {
        tile_idx := tile.x + tile.y * level.width
        if tile.x >= 0 && tile.x < level.width && tile.y >= 0 && tile.y < level.height {
            level.tile_refs[tile_idx].valid = false
        }

        orientation = orientation_turn(orientation, opposite_direction(dir))
        tile = tile_move(tile, orientation)
    }

    for i := 0; i < len(level.tile_refs); {
        if !level.tile_refs[i].valid {
            unordered_remove(&level.tile_refs, i)
        } else {
            i += 1
        }
    }
    
    if len(level.tile_refs) == 0 {
        return false
    }

    random_tile_idx := rand.choice(level.tile_refs[:]).index
    level.tiles[random_tile_idx] = .Apple
    return true
}

level_draw :: proc(level: Level, x0, y0: f32) {
    rl.DrawRectangleV(
        {x0, y0},
        {(f32(level.width) + 0.4) * level.tile_size, (f32(level.width) + 0.4) * level.tile_size},
        {28, 24, 18, 255}
    )
    x0 := x0 + level.tile_size  * 0.2
    y0 := y0 + level.tile_size  * 0.2
    for i in 0..<level.width {
        for j in 0..<level.height {
            x := x0 + f32(i) * level.tile_size
            y := y0 + f32(j) * level.tile_size
            color := (i + j) % 2 == 0 ? rl.BROWN : rl.DARKBROWN
            rl.DrawRectangleV({x, y}, {level.tile_size, level.tile_size}, color)
            if level.tiles[i + j * level.width] == .Apple {
                rl.DrawCircleV({x, y} + (level.tile_size / 2), 0.4 * level.tile_size, {135, 25, 32, 255})
                rl.DrawCircleV({x, y} + (level.tile_size / 2), 0.3 * level.tile_size, rl.RED)
            }
        }
    }
    snake_draw(level.snake, x0, y0, level.tile_size)
}

level_put_turn_request ::proc(level: ^Level, request: Orientation) {
    level.snake.orientation_request = request
}


level_get_bounds :: proc(level: Level) -> (w, h: f32) {
    w = (f32(level.width) + 0.4) * level.tile_size
    h = (f32(level.height) + 0.4) * level.tile_size
    return
}
