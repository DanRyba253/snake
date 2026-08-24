package snake

import "core:strconv"
import "core:os"
import "core:fmt"
import rl "vendor:raylib"


bend_shader_code := cstring(#load("bend_shader.fs"))
bend_shader: rl.Shader
xLoc, baseLoc, factorLoc, cutoffLoc, borderThicknessLocBend,
colorInnerLocBend, colorBorderLocBend: i32

straight_shader_code := cstring(#load("straight_shader.fs"))
straight_shader: rl.Shader
baseRadiusLoc, endRadiusLoc, maxYLoc, borderThicknessLocStraight,
colorInnerLocStraight, colorBorderLocStraight: i32

target: rl.RenderTexture2D

main :: proc() {
    when !ODIN_DEBUG {
        rl.SetTraceLogLevel(.NONE)
    }

    level_width := 10
    level_height := 10

    if len(os.args) >= 2 {
        w, ok := strconv.parse_int(os.args[1])
        if ok {
            level_width = w
        }
    }

    if len(os.args) >= 3 {
        h, ok := strconv.parse_int(os.args[2])
        if ok {
            level_height = h
        }
    }
    
    rl.InitWindow(500, 500, "Snake")

    monitor := rl.GetCurrentMonitor()
    monitor_width := f32(rl.GetMonitorWidth(monitor)) * 0.9
    monitor_height := f32(rl.GetMonitorHeight(monitor)) * 0.9
    tile_size := min(50, monitor_width / f32(level_width), monitor_height / f32(level_height))

    screen_width := i32(f32(level_width) * tile_size + tile_size * 0.4)
    screen_height := i32(f32(level_height) * tile_size + tile_size * 0.4)

    rl.SetWindowSize(screen_width, screen_height)
    rl.SetTargetFPS(60)

    bend_shader = rl.LoadShaderFromMemory(nil, bend_shader_code)
    defer rl.UnloadShader(bend_shader)
    xLoc = rl.GetShaderLocation(bend_shader, "x")
    baseLoc = rl.GetShaderLocation(bend_shader, "base")
    factorLoc = rl.GetShaderLocation(bend_shader, "factor")
    cutoffLoc = rl.GetShaderLocation(bend_shader, "cutoff")
    borderThicknessLocBend = rl.GetShaderLocation(bend_shader, "borderThickness")
    colorInnerLocBend = rl.GetShaderLocation(bend_shader, "colorInner")
    colorBorderLocBend = rl.GetShaderLocation(bend_shader, "colorBorder")

    straight_shader = rl.LoadShaderFromMemory(nil, straight_shader_code)
    defer rl.UnloadShader(straight_shader)
    baseRadiusLoc = rl.GetShaderLocation(straight_shader, "baseRadius")
    endRadiusLoc = rl.GetShaderLocation(straight_shader, "endRadius")
    maxYLoc = rl.GetShaderLocation(straight_shader, "maxY")
    borderThicknessLocStraight = rl.GetShaderLocation(straight_shader, "borderThickness")
    colorInnerLocStraight = rl.GetShaderLocation(straight_shader, "colorInner")
    colorBorderLocStraight = rl.GetShaderLocation(straight_shader, "colorBorder")

    target = rl.LoadRenderTexture(500, 500)
    defer rl.UnloadRenderTexture(target)
    
    update_result: LevelUpdateResult

    level, level_err := level_init(
        tile_size = tile_size,
        width = level_width, height = level_height,
        snake_x = level_width / 2, snake_y = level_height / 2,
        snake_speed = 5,
        snake_length = 1,
        snake_orientation = .Up
    )
    if level_err != nil {
        fmt.eprintln("Failed to create level")
        os.exit(1)
    }
    defer level_destroy(level)
    level_add_new_random_apple(&level)

    for !rl.WindowShouldClose() && update_result == .Success {
        update_result = level_update(&level, rl.GetFrameTime()) 

        if rl.IsKeyPressed(.DOWN) {
            level_put_turn_request(&level, .Down)
        }

        if rl.IsKeyPressed(.UP) {
            level_put_turn_request(&level, .Up)
        }

        if rl.IsKeyPressed(.RIGHT) {
            level_put_turn_request(&level, .Right)
        }

        if rl.IsKeyPressed(.LEFT) {
            level_put_turn_request(&level, .Left)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        level_w, level_h := level_get_bounds(level)
        screen_w := f32(rl.GetScreenWidth())
        screen_h := f32(rl.GetScreenHeight())
        x0 := (screen_w - level_w) / 2
        y0 := (screen_h - level_h) / 2
        level_draw(level, x0, y0)
        rl.EndDrawing()
    }

    fmt.printfln("Game over. You scored %v point%s!", level.score, ending(level.score))
    if update_result == .GameWin {
        fmt.println("You won the game!")
    }
}

ending :: proc(n: int) -> string {
    if n == 1 {
        return ""
    }
    return "s"
}
