#pragma once

#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

namespace mermaid {

struct StartOptions {
  std::string data_dir;
  std::string save_dir;
  std::string os_id;
  int sidecut = -1;
  bool vsync = true;
};

enum HostState {
  kStateIdle = 0,
  kStateStarting = 1,
  kStateRunning = 2,
  kStateStopped = 3,
  kStateError = 4,
  kStateExited = 5,
};

class EngineHost {
public:
  static EngineHost &Get();

  void Start(const StartOptions &options);
  void Stop();
  void Pause();
  void Resume();
  void SendKey(int key_code, bool down);
  int State() const { return state_.load(); }

  void OnSurfaceCreated(void *window);
  void OnSurfaceChanged(void *window);
  void OnSurfaceDestroyed(void *window);
  void OnTouch(int action, float x, float y);

private:
  struct Command {
    enum Type {
      kStart,
      kStop,
      kPause,
      kResume,
      kKeyDown,
      kKeyUp,
      kTouchDown,
      kTouchMove,
      kTouchUp,
      kSurfaceCreated,
      kSurfaceChanged,
      kSurfaceDestroyed,
    };

    Type type = kStop;
    StartOptions options;
    int key_code = 0;
    void *window = nullptr;
    float x = 0.0f;
    float y = 0.0f;
  };

  struct InputEvent {
    bool is_key = false;
    bool is_move = false;
    bool down = false;
    int key = 0;
    float x = 0.0f;
    float y = 0.0f;
  };

  EngineHost() = default;
  EngineHost(const EngineHost &) = delete;
  EngineHost &operator=(const EngineHost &) = delete;

  void Post(const Command &command);
  void EnsureThread();
  void ThreadMain();

  std::mutex mutex_;
  std::condition_variable cond_;
  std::deque<Command> commands_;
  std::thread thread_;
  bool thread_started_ = false;
  std::atomic<int> state_{kStateIdle};
};

} // namespace mermaid
