#include "host/engine_host.h"

#include <hilog/log.h>
#include <native_window/external_window.h>

#include <chrono>
#include <cstdint>
#include <utility>
#include <vector>

#include "audio/audio.h"
#include "core/engine_context.h"
#include "host/ohos_renderer.h"
#include "render/compositor.h"
#include "script/asb_parser.h"
#include "script/lua_engine.h"

namespace mermaid {

namespace {

constexpr unsigned int kLogDomain = 0x4D45;
constexpr const char *kLogTag = "ArtemisHost";
constexpr float kTouchSlop = 16.0f;

void LogInfo(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

void LogError(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

} // namespace

EngineHost &EngineHost::Get() {
  static EngineHost host;
  return host;
}

void EngineHost::Post(const Command &command) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    commands_.push_back(command);
  }
  cond_.notify_all();
}

void EngineHost::EnsureThread() {
  if (thread_started_) {
    return;
  }
  thread_started_ = true;
  thread_ = std::thread([this]() { ThreadMain(); });
}

void EngineHost::Start(const StartOptions &options) {
  EnsureThread();
  Command command;
  command.type = Command::kStart;
  command.options = options;
  Post(command);
}

void EngineHost::Stop() {
  Command command;
  command.type = Command::kStop;
  Post(command);
}

void EngineHost::Pause() {
  Command command;
  command.type = Command::kPause;
  Post(command);
}

void EngineHost::Resume() {
  Command command;
  command.type = Command::kResume;
  Post(command);
}

void EngineHost::SendKey(int key_code, bool down) {
  Command command;
  command.type = down ? Command::kKeyDown : Command::kKeyUp;
  command.key_code = key_code;
  Post(command);
}

void EngineHost::OnSurfaceCreated(void *window) {
  LogInfo("surface created event ptr=" + std::to_string(reinterpret_cast<uintptr_t>(window)));
  Command command;
  command.type = Command::kSurfaceCreated;
  command.window = window;
  Post(command);
}

void EngineHost::OnSurfaceChanged(void *window) {
  LogInfo("surface changed event ptr=" + std::to_string(reinterpret_cast<uintptr_t>(window)));
  Command command;
  command.type = Command::kSurfaceChanged;
  command.window = window;
  Post(command);
}

void EngineHost::OnSurfaceDestroyed(void *window) {
  LogInfo("surface destroyed event ptr=" + std::to_string(reinterpret_cast<uintptr_t>(window)));
  Command command;
  command.type = Command::kSurfaceDestroyed;
  command.window = window;
  Post(command);
}

void EngineHost::OnTouch(int action, float x, float y) {
  Command command;
  command.type = action == 0 ? Command::kTouchDown
               : action == 2 ? Command::kTouchMove
                             : Command::kTouchUp;
  command.x = x;
  command.y = y;
  Post(command);
}

void EngineHost::ThreadMain() {
  artc::EngineContext context;
  artc::EngineContext::SetCurrent(&context);
  OhosRenderer renderer;

  StartOptions options;
  bool running = false;
  bool opened = false;
  bool booted = false;
  bool paused = false;
  bool window_created = false;
  bool window_resized = false;
  bool window_destroyed = false;
  void *window = nullptr;
  uint64_t drawn_rev = ~0ULL;
  bool last_drew = false;
  std::deque<InputEvent> input;
  float touch_down_x = 0.0f;
  float touch_down_y = 0.0f;
  bool touch_dragging = false;

  for (;;) {
    std::deque<Command> batch;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      const int wait_ms = (running && booted) ? (last_drew ? 1 : 16) : 200;
      cond_.wait_for(lock, std::chrono::milliseconds(wait_ms), [this]() { return !commands_.empty(); });
      batch.swap(commands_);
    }

    for (const Command &command : batch) {
      switch (command.type) {
        case Command::kStart:
          options = command.options;
          running = true;
          paused = false;
          state_.store(kStateStarting);
          break;
        case Command::kStop:
          running = false;
          break;
        case Command::kPause:
          paused = true;
          if (opened) {
            context.audio().PauseAll();
          }
          break;
        case Command::kResume:
          paused = false;
          if (opened) {
            context.audio().ResumeAll();
          }
          break;
        case Command::kKeyDown:
        case Command::kKeyUp: {
          InputEvent event;
          event.is_key = true;
          event.down = command.type == Command::kKeyDown;
          event.key = command.key_code;
          input.push_back(event);
          break;
        }
        case Command::kTouchDown:
        case Command::kTouchMove:
        case Command::kTouchUp: {
          InputEvent event;
          event.is_key = false;
          event.is_move = command.type == Command::kTouchMove;
          event.down = command.type == Command::kTouchDown;
          event.x = command.x;
          event.y = command.y;
          input.push_back(event);
          break;
        }
        case Command::kSurfaceCreated:
          window = command.window;
          window_created = true;
          break;
        case Command::kSurfaceChanged:
          window = command.window;
          window_resized = true;
          break;
        case Command::kSurfaceDestroyed:
          window = nullptr;
          window_destroyed = true;
          break;
      }
    }

    if (!running) {
      input.clear();
      if (opened) {
        if (context.Started()) {
          context.Shutdown();
        }
        opened = false;
        booted = false;
        drawn_rev = ~0ULL;
        state_.store(kStateIdle);
        LogInfo("engine stopped");
      }
      continue;
    }

    if (!opened) {
      if (!context.Open(options.data_dir, options.os_id, {}, options.save_dir)) {
        LogError("engine open failed: " + options.data_dir);
        state_.store(kStateError);
        running = false;
        continue;
      }
      opened = true;
      LogInfo("engine opened stage " + std::to_string(context.stageW()) + "x" +
              std::to_string(context.stageH()));
    }

    if (window_destroyed) {
      window_destroyed = false;
      renderer.Shutdown();
      if (context.Started()) {
        context.compositor().ReleaseGl();
        context.ResetSession();
      }
      booted = false;
      drawn_rev = ~0ULL;
    }
    if (window_created) {
      window_created = false;
      renderer.Shutdown();
      if (context.Started()) {
        context.compositor().ReleaseGl();
        context.ResetSession();
      }
      booted = false;
      drawn_rev = ~0ULL;
      if (window != nullptr) {
        if (!renderer.Init(window, options.vsync)) {
          LogError("egl init failed: " + renderer.LastError());
          state_.store(kStateError);
          running = false;
          continue;
        }
      }
    } else if (window_resized) {
      window_resized = false;
      if (window != nullptr) {
        if (renderer.Ready()) {
          if (!renderer.UpdateSurface(window)) {
            LogError("egl resize failed: " + renderer.LastError());
            renderer.Shutdown();
            if (context.Started()) {
              context.compositor().ReleaseGl();
              context.ResetSession();
            }
            booted = false;
            if (!renderer.Init(window, options.vsync)) {
              LogError("egl reinit failed: " + renderer.LastError());
              state_.store(kStateError);
              running = false;
              continue;
            }
          }
          drawn_rev = ~0ULL;
        } else if (!renderer.Init(window, options.vsync)) {
          LogError("egl init failed: " + renderer.LastError());
          state_.store(kStateError);
          running = false;
          continue;
        }
      }
    }

    if (renderer.Ready() && !booted) {
      if (!context.Start(true)) {
        LogError("engine start failed");
        state_.store(kStateError);
        running = false;
        continue;
      }
      if (!context.BootFramework(false)) {
        LogError("engine boot framework failed");
        state_.store(kStateError);
        running = false;
        continue;
      }
      const bool sidecut = options.sidecut >= 0
        ? options.sidecut == 1
        : context.ini().GetInt("COMMON", "SIDECUT", 0) == 1;
      renderer.SetStage(context.stageW(), context.stageH(), sidecut);
      booted = true;
      last_drew = false;
      state_.store(kStateRunning);
      LogInfo("engine booted");
    }

    if (!booted) {
      input.clear();
      std::this_thread::sleep_for(std::chrono::milliseconds(16));
      continue;
    }

    artc::LuaEngine &lua = context.lua();
    artc::AsbRunner &runner = context.runner();

    if (paused) {
      input.clear();
      std::this_thread::sleep_for(std::chrono::milliseconds(32));
      continue;
    }

    for (const InputEvent &event : input) {
      if (event.is_key) {
        if (event.down) {
          lua.PushKeyDown(event.key);
        } else {
          lua.PushKeyUp(event.key);
        }
      } else if (event.is_move) {
        if (!touch_dragging) {
          const float dx = event.x - touch_down_x;
          const float dy = event.y - touch_down_y;
          if (dx * dx + dy * dy > kTouchSlop * kTouchSlop) {
            touch_dragging = true;
          }
        }
        lua.SetMousePoint(renderer.StageX(event.x), renderer.StageY(event.y));
        if (touch_dragging) {
          lua.DragMove(renderer.StageX(event.x), renderer.StageY(event.y));
        }
      } else {
        lua.SetMousePoint(renderer.StageX(event.x), renderer.StageY(event.y));
        if (event.down) {
          touch_down_x = event.x;
          touch_down_y = event.y;
          touch_dragging = false;
          lua.PushKeyDown(1);
          lua.SetTouchCount(1);
          lua.BeginDrag(renderer.StageX(event.x), renderer.StageY(event.y));
        } else {
          lua.PushKeyUp(1);
          lua.SetTouchCount(0);
          const bool was_dragging = touch_dragging || lua.DragMoved();
          lua.EndDrag();
          touch_dragging = false;
          if (!was_dragging) {
            lua.ClickAt(renderer.StageX(event.x), renderer.StageY(event.y));
          }
        }
      }
    }
    input.clear();

    auto drain = [&]() {
      while (!lua.IsWaiting() && lua.HasQueuedTag()) {
        std::string name;
        std::vector<std::pair<std::string, std::string>> attrs;
        if (!lua.PopQueuedTag(&name, &attrs)) {
          break;
        }
        if (name == "jump" || name == "call") {
          std::string file;
          std::string label;
          for (const auto &kv : attrs) {
            if (kv.first == "file") {
              file = kv.second;
            } else if (kv.first == "label") {
              label = kv.second;
            }
          }
          runner.Jump(file, label);
        } else {
          lua.DispatchTag(name, attrs, false);
        }
      }
    };

    lua.RunEnterFrame();
    drain();

    if (runner.Loaded() && !runner.Halted() && !lua.IsWaiting()) {
      for (int steps = 0; steps < 4 && runner.Loaded() && !runner.Halted() && !lua.IsWaiting(); ++steps) {
        runner.ExecuteLine(lua);
        drain();
      }
    } else if (!lua.IsWaiting() && lua.HasQueuedTag()) {
      drain();
    }

    context.compositor().Update(lua.NowMs());
    const double now = lua.NowMs();
    const bool animating = context.compositor().PendingAnimationMs(now) > 0 ||
                           context.compositor().TransitionActive() ||
                           context.compositor().PendingTextMs(now) > 0;
    last_drew = false;
    if (drawn_rev != context.compositor().Revision() || animating) {
      renderer.Clear();
      context.compositor().Draw();
      renderer.Present();
      drawn_rev = context.compositor().Revision();
      last_drew = true;
    }
    lua.EndFrame();

    if (lua.ConsumeResetRequest()) {
      LogInfo("engine reset requested");
      context.compositor().ReleaseGl();
      context.ResetSession();
      booted = false;
      drawn_rev = ~0ULL;
      continue;
    }
    if (lua.ConsumeExitRequest()) {
      LogInfo("engine exit requested");
      state_.store(kStateExited);
      running = false;
    }
  }

  if (context.Started()) {
    context.Shutdown();
  }
  renderer.Shutdown();
  artc::EngineContext::SetCurrent(nullptr);
}

} // namespace mermaid
