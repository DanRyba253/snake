package snake

import "vendor:raylib/rlgl"
import "core:math"
import rl "vendor:raylib"

Direction :: enum int {
    Straight =  0,
    Left     = -1,
    Right    =  1,
}

Orientation :: enum {
    Up = 1,
    Right = 2,
    Down = 3,
    Left = 4,
}

snake_draw :: proc(snake: Snake, x0, y0: f32, tile_size: f32) {
    head_x, head_y := get_end_coords(
        x0, y0,
        snake.head_tile.x, snake.head_tile.y,
        tile_size,
        snake.orientation,
        snake.head_rotation,
        snake.progress
    )

    rl.DrawCircleV({head_x, head_y}, (snake.head_radius + snake.outline_thickness) * tile_size, snake.outline_color)

    rl.BeginShaderMode(shader)
    draw_bend(
        x0, y0,
        snake.head_tile.x, snake.head_tile.y,
        tile_size,
        snake.orientation,
        snake.head_rotation,
        snake.head_radius + (snake.tail_radius - snake.head_radius) * (snake.progress / snake.length),
        snake.head_radius,
        snake.progress,
        snake.outline_thickness,
        snake.body_color,
        snake.outline_color,
    )

    i := 0
    orientation := opposite_orientation(snake.orientation)
    tile := snake.head_tile
    length := snake.length - snake.progress

    for length > 0 {
        used_length := min(1, length)
        dir := Direction.Straight
        if i < len(snake.body_path) {
            dir = opposite_direction(snake.body_path[i])
        }
        tile = tile_move(tile, orientation)
        i += 1
        base_radius := snake.tail_radius + (snake.head_radius - snake.tail_radius) * (length / snake.length)
        end_radius := snake.tail_radius + (snake.head_radius - snake.tail_radius) * ((length - used_length) / snake.length)
        length -= used_length

        if length <= 0 {
            tail_x, tail_y := get_end_coords(
                x0, y0,
                tile.x, tile.y,
                tile_size,
                orientation,
                f32(dir),
                used_length
            )
            
            tail_direction := f32(90) * f32(dir) * used_length
            angle_a, angle_b: f32
            switch orientation {
            case .Up:
                angle_a = 179
                angle_b = 361
            case .Down:
                angle_a = -1
                angle_b = 181
            case .Left:
                angle_a = 89
                angle_b = 271
            case .Right:
                angle_a = 269
                angle_b = 451
            }
            angle_a += tail_direction
            angle_b += tail_direction

            rl.EndShaderMode()

            rl.DrawCircleSector(
                {tail_x, tail_y},
                (snake.tail_radius + snake.outline_thickness) * 7/8 * tile_size,
                angle_a, angle_b, 1, snake.outline_color
            )

            rl.BeginShaderMode(shader)
        }

        draw_bend(
            x0, y0,
            tile.x, tile.y,
            tile_size,
            orientation,
            f32(dir),
            base_radius,
            end_radius,
            used_length,
            snake.outline_thickness,
            snake.body_color,
            snake.outline_color
        )

        if length <= 0 {
            tail_x, tail_y := get_end_coords(
                x0, y0,
                tile.x, tile.y,
                tile_size,
                orientation,
                f32(dir),
                used_length
            )
            rl.EndShaderMode()
            rl.DrawCircleV({tail_x, tail_y}, (snake.tail_radius * 4/5) * tile_size, snake.body_color)
        }

        orientation = orientation_turn(orientation, dir)

    }

    rl.DrawCircleV({head_x, head_y}, (snake.head_radius) * tile_size, snake.body_color)

    head_direction := f32(90) * f32(snake.head_rotation) * snake.progress
    angle_a, angle_b: f32
    switch snake.orientation {
    case .Up:
        angle_a = 180
        angle_b = 360
    case .Down:
        angle_a = 0
        angle_b = 180
    case .Left:
        angle_a = 90
        angle_b = 270
    case .Right:
        angle_a = 270
        angle_b = 450
    }
    angle_a += head_direction
    angle_b += head_direction
    
    dya, dxa := math.sincos(angle_a * math.PI / 180)
    dyb, dxb := math.sincos(angle_b * math.PI / 180)

    pos_a := [2]f32{
        head_x + dxa * snake.head_radius * tile_size * 0.5,
        head_y + dya * snake.head_radius * tile_size * 0.5,
    }
    pos_b := [2]f32{
        head_x + dxb * snake.head_radius * tile_size * 0.5,
        head_y + dyb * snake.head_radius * tile_size * 0.5,
    }
    eye_radius := snake.head_radius * tile_size * 0.35
    pupil_radius := snake.head_radius * tile_size * 0.15

    rl.DrawCircleV(pos_a, eye_radius, rl.RAYWHITE)
    rl.DrawCircleV(pos_b, eye_radius, rl.RAYWHITE)
    rl.DrawCircleV(pos_a, pupil_radius, rl.BLACK)
    rl.DrawCircleV(pos_b, pupil_radius, rl.BLACK)
    
}

draw_bend :: proc(
    x0, y0: f32,
    cell_i, cell_j: int,
    tile_size: f32,
    orientation: Orientation,
    rotation: f32,
    base_radius: f32,
    end_radius: f32,
    length: f32,
    outline_thickness: f32,
    color_inner: rl.Color,
    color_border: rl.Color,
) {
    flip_x := rotation < 0
    theta := math.PI / 2 * (1 - abs(rotation) / 2) 
    re := end_radius
    rb := base_radius

    dest_x := x0 + f32(cell_i) * tile_size + tile_size / 2
    dest_y := y0 + f32(cell_j) * tile_size + tile_size / 2

    cell_rotation := f32(0)
    #partial switch orientation {
    case .Left:
        cell_rotation = 90
    case .Right:
        cell_rotation = -90
    case .Up:
        cell_rotation = 180
    }

    changed_uniforms := false

    borderThickness_new := outline_thickness
    colorInner_new := [3]f32{f32(color_inner.r), f32(color_inner.g), f32(color_inner.b)} / 255
    colorBorder_new := [3]f32{f32(color_border.r), f32(color_border.g), f32(color_border.b)} / 255
    x_new, cutoff_new, factor_new: f32
    base: f32
    
    if abs(theta - math.PI / 2) > 0.05 {
        x_new = -1.0 / 2 * math.tan(theta)
        cutoff_new = 4 * abs(math.PI / 2 - theta) / math.PI * length
        factor_new = (re - rb) / cutoff_new
        base = rb
    } else {
        x_new = x
        cutoff_new = length
        factor_new = (re - rb) / cutoff_new
        base = -rb
    }

    if borderThickness_new != borderThickness ||
       colorInner_new != colorInner ||
       colorBorder_new != colorBorder ||
       abs(x_new - x) > 0.001 ||
       abs(cutoff_new - cutoff) > 0.001 ||
       abs(factor_new - factor) > 0.001 {
        changed_uniforms = true
    }

    borderThickness = borderThickness_new
    colorInner = colorInner_new
    colorBorder = colorBorder_new
    x = x_new
    cutoff = cutoff_new
    factor = factor_new

    if changed_uniforms {
        rlgl.DrawRenderBatchActive()
        rl.SetShaderValue(shader, xLoc, &x_new, .FLOAT)
        rl.SetShaderValue(shader, factorLoc, &factor_new, .FLOAT)
        rl.SetShaderValue(shader, cutoffLoc, &cutoff_new, .FLOAT)
        rl.SetShaderValue(shader, borderThicknessLoc, &borderThickness_new, .FLOAT)
        rl.SetShaderValue(shader, colorInnerLoc, &colorInner_new, .VEC3)
        rl.SetShaderValue(shader, colorBorderLoc, &colorBorder_new, .VEC3)
    }

    src := rl.Rectangle{0, 0, f32(target.texture.width), f32(target.texture.height)}
    if flip_x {
        src = rl.Rectangle{0, 0, -f32(target.texture.height), f32(target.texture.height)}
    }

    rl.DrawTexturePro(
        target.texture,
        src,
        {dest_x, dest_y, tile_size, tile_size},
        {tile_size / 2, tile_size / 2}, cell_rotation, transmute(rl.Color)base
    )
}

opposite_orientation :: proc(ori: Orientation) -> Orientation {
    switch ori {
    case .Up:
        return .Down
    case .Down:
        return .Up
    case .Left:
        return .Right
    case .Right:
        return .Left
    }
    return ori
}

tile_move :: proc(tile: [2]int, ori: Orientation) -> (res: [2]int) {
    res = tile
    switch ori {
    case .Up:
        res.y -= 1
    case .Down:
        res.y += 1
    case .Left:
        res.x -= 1
    case .Right:
        res.x += 1
    }
    return
}

orientation_turn :: proc(ori: Orientation, dir: Direction) -> Orientation {
    #partial switch dir {
    case .Left:
        switch ori {
        case .Left:
            return .Down
        case .Up:
            return .Left
        case .Right:
            return .Up
        case .Down:
            return .Right
        }
    case .Right:
        switch ori {
        case .Left:
            return .Up
        case .Up:
            return .Right
        case .Right:
            return .Down
        case .Down:
            return .Left
        }
    }
    return ori
}

opposite_direction :: proc(dir: Direction) -> (res: Direction) {
    switch dir {
    case .Left:
        res = .Right
    case .Right:
        res = .Left
    case .Straight:
        res = .Straight
    }
    return
}

get_end_coords :: proc(
    x0, y0: f32,
    cell_i, cell_j: int,
    tile_size: f32,
    orientation: Orientation,
    rotation: f32,
    length: f32,
) ->(x: f32, y: f32) {
    x = tile_size * length * 
        math.cos(math.PI * rotation / 4) *
        math.sin(math.PI * rotation * length / 4) *
        sinc(rotation * length / 4) /
        sinc(rotation / 4)

    y = tile_size * length *
        math.cos(math.PI * rotation / 4) *
        sinc(rotation * length / 2) /
        sinc(rotation / 4) - tile_size / 2

    #partial switch orientation {
    case .Up:
        y = -y
    case .Down:
        x = -x
    case .Left:
        temp := -y
        y = -x
        x = temp
    case .Right:
        temp := y
        y = x
        x = temp
    }
    
    x += f32(cell_i) * tile_size + tile_size / 2 + x0
    y += f32(cell_j) * tile_size + tile_size / 2 + y0
    return
}

// sinc(x) == sin(pi*x) / (pi * x)
sinc :: proc(x: f32) -> f32 {
    if abs(x) < 1e-4 {
        return 1.0 - (x * x * 3.289868133696)
    }
    pix := x * math.PI
    return math.sin(pix) / pix
}

TileType :: enum {
    Empty,
    Apple,
    Wall,
}

TileProc :: #type proc(x, y: int, user_data: rawptr) -> TileType

EatAppleProc :: #type proc(x, y: int, user_data: rawptr)

SnakeUpdateResult :: enum {
    Success,
    GameOverWall,
    GameOverSelf,
}

Snake :: struct {
    head_tile: [2]int,
    speed: f32,
    orientation: Orientation,
    body_path: [dynamic]Direction,
    head_rotation_goal: Direction,
    orientation_request: Orientation, /* nil == no request */
    progress: f32,
    head_rotation: f32,
    need_to_grow: f32,
    head_radius: f32,
    tail_radius: f32,
    length: f32,
    body_color: rl.Color,
    outline_color: rl.Color,
    outline_thickness: f32,
    user_data: rawptr,
}

snake_update :: proc(
    snake: ^Snake,
    delta_time: f32,
    tile_at: TileProc,
    eat_apple: EatAppleProc
) -> SnakeUpdateResult {
    delta_time := delta_time
    for delta_time > 0 {
        current_tile_type := tile_at(snake.head_tile.x, snake.head_tile.y, snake.user_data)
        if current_tile_type == .Wall {
            return .GameOverWall
        }
        
        orientation := opposite_orientation(snake.orientation)
        tile := tile_move(snake.head_tile, opposite_orientation(snake.orientation))
        for dir in snake.body_path {
            if tile == snake.head_tile {
                return .GameOverSelf
            }
            orientation = orientation_turn(orientation, opposite_direction(dir))
            tile = tile_move(tile, orientation)
        }
        
        distance_to_next_tile := 1 - snake.progress
        time_till_next_tile := distance_to_next_tile / snake.speed
        used_delta_time := min(time_till_next_tile, delta_time)
        delta_time -= used_delta_time
        reached_next_cell := used_delta_time == time_till_next_tile
        new_progress := snake.progress + used_delta_time * snake.speed
        distance_traveled := new_progress - snake.progress

        grown := min(snake.need_to_grow, distance_traveled)
        snake.length += grown
        snake.need_to_grow -= grown

        if current_tile_type == .Apple && snake.progress < 0.5 && new_progress >= 0.5 {
            snake.need_to_grow = reached_next_cell ? 0.5 : 1.5 - new_progress
            snake.length += reached_next_cell ? 0.5 : new_progress - 0.5
            eat_apple(snake.head_tile.x, snake.head_tile.y, snake.user_data)
        }

        if reached_next_cell {
            switch snake.orientation {
            case .Up:
                switch snake.head_rotation_goal {
                case .Straight:
                    snake.head_tile += {0, -1}
                case .Right:
                    snake.head_tile += {1,  0}
                    snake.orientation = .Right
                case .Left:
                    snake.head_tile += {-1, 0}
                    snake.orientation = .Left
                }
            case .Down:
                switch snake.head_rotation_goal {
                case .Straight:
                    snake.head_tile += {0,  1}
                case .Right:
                    snake.head_tile += {-1, 0}
                    snake.orientation = .Left
                case .Left:
                    snake.head_tile += {1,  0}
                    snake.orientation = .Right
                }
            case .Left:
                switch snake.head_rotation_goal {
                case .Straight:
                    snake.head_tile += {-1, 0}
                case .Right:
                    snake.head_tile += {0, -1}
                    snake.orientation = .Up
                case .Left:
                    snake.head_tile += {0,  1}
                    snake.orientation = .Down
                }
            case .Right:
                switch snake.head_rotation_goal {
                case .Straight:
                    snake.head_tile += {1,  0}
                case .Right:
                    snake.head_tile += {0,  1}
                    snake.orientation = .Down
                case .Left:
                    snake.head_tile += {0, -1}
                    snake.orientation = .Up
                }
            }

            inject_at(&snake.body_path, 0, snake.head_rotation_goal)

            if snake.need_to_grow == 0 {
                pop(&snake.body_path)
            }

            snake.head_rotation_goal = .Straight
            snake.progress = 0
            snake.head_rotation = 0

            request1: if snake.orientation_request != nil {
                new_head_rotation_goal, ok := try_process_orientation_request(
                    snake.orientation,
                    snake.orientation_request
                )
                if !ok {
                    break request1
                }
                snake.head_rotation_goal = new_head_rotation_goal
                snake.head_rotation = f32(snake.head_rotation_goal)
                snake.orientation_request = nil
            }
        } else {
            request2: if new_progress < 0.75 && snake.orientation_request != nil {
                new_head_rotation_goal, ok := try_process_orientation_request(
                    snake.orientation,
                    snake.orientation_request
                )
                if !ok {
                    break request2
                }
                snake.head_rotation_goal = new_head_rotation_goal
                snake.orientation_request = nil
            }

            snake.head_rotation += (f32(snake.head_rotation_goal) - snake.head_rotation) *
                                   (new_progress - snake.progress) / (1 - snake.progress)
            snake.progress = new_progress
        }
    }
    return .Success
}

try_process_orientation_request :: proc(old, new: Orientation) -> (res: Direction, ok: bool) {
    ok = true
    switch old {
    case .Left:
        switch new {
        case .Left:
            res = .Straight  
        case .Right:
            ok = false
        case .Up:
            res = .Right
        case .Down:
            res = .Left
        }
    case .Right:
        switch new {
        case .Left:
            ok = false
        case .Right:
            res = .Straight
        case .Up:
            res = .Left
        case .Down:
            res = .Right
        }
    case .Up:
        switch new {
        case .Left:
            res = .Left 
        case .Right:
            res = .Right
        case .Up:
            res = .Straight
        case .Down:
            ok = false
        }
    case .Down:
        switch new {
        case .Left:
            res = .Right  
        case .Right:
            res = .Left
        case .Up:
            ok = false
        case .Down:
            res = .Straight
        }
    }
    return
}
