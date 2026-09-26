#include <ace/xcomponent/native_interface_xcomponent.h>
#include <hilog/log.h>
#include <napi/native_api.h>

#include <string>
#include <vector>

#include "host/engine_host.h"

namespace {

constexpr unsigned int kLogDomain = 0x4D45;
constexpr const char *kLogTag = "ArtemisHost";

void LogInfo(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

void LogError(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

std::string GetStringProperty(napi_env env, napi_value object, const char *name) {
  napi_value value = nullptr;
  if (napi_get_named_property(env, object, name, &value) != napi_ok || value == nullptr) {
    return "";
  }
  size_t length = 0;
  if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
    return "";
  }
  std::vector<char> buffer(length + 1, '\0');
  size_t written = 0;
  if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &written) != napi_ok) {
    return "";
  }
  return std::string(buffer.data(), written);
}

int MapKeyCode(OH_NativeXComponent_KeyCode key_code) {
  switch (key_code) {
    case KEY_BACK:
      return 8;
    case KEY_ENTER:
    case KEY_DPAD_CENTER:
    case KEY_SPACE:
      return 13;
    case KEY_DPAD_UP:
      return 38;
    case KEY_DPAD_DOWN:
      return 40;
    case KEY_DPAD_LEFT:
      return 37;
    case KEY_DPAD_RIGHT:
      return 39;
    case KEY_MENU:
      return 93;
    case KEY_VOLUME_UP:
      return 137;
    case KEY_VOLUME_DOWN:
      return 136;
    default:
      return -1;
  }
}

void OnSurfaceCreated(OH_NativeXComponent *component, void *window) {
  mermaid::EngineHost::Get().OnSurfaceCreated(window);
}

void OnSurfaceChanged(OH_NativeXComponent *component, void *window) {
  mermaid::EngineHost::Get().OnSurfaceChanged(window);
}

void OnSurfaceDestroyed(OH_NativeXComponent *component, void *window) {
  mermaid::EngineHost::Get().OnSurfaceDestroyed(window);
}

void DispatchTouchEvent(OH_NativeXComponent *component, void *window) {
  OH_NativeXComponent_TouchEvent touch_event;
  if (OH_NativeXComponent_GetTouchEvent(component, window, &touch_event) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  mermaid::EngineHost::Get().OnTouch(static_cast<int>(touch_event.type), touch_event.x,
                                     touch_event.y);
}

void OnKeyEvent(OH_NativeXComponent *component, void *window) {
  OH_NativeXComponent_KeyEvent *key_event = nullptr;
  if (OH_NativeXComponent_GetKeyEvent(component, &key_event) != OH_NATIVEXCOMPONENT_RESULT_SUCCESS ||
      key_event == nullptr) {
    return;
  }
  OH_NativeXComponent_KeyAction action;
  OH_NativeXComponent_KeyCode key_code;
  if (OH_NativeXComponent_GetKeyEventAction(key_event, &action) != OH_NATIVEXCOMPONENT_RESULT_SUCCESS ||
      OH_NativeXComponent_GetKeyEventCode(key_event, &key_code) != OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  const int engine_key = MapKeyCode(key_code);
  if (engine_key < 0) {
    return;
  }
  if (action == OH_NATIVEXCOMPONENT_KEY_ACTION_DOWN) {
    mermaid::EngineHost::Get().SendKey(engine_key, true);
  } else if (action == OH_NATIVEXCOMPONENT_KEY_ACTION_UP) {
    mermaid::EngineHost::Get().SendKey(engine_key, false);
  }
}

OH_NativeXComponent_Callback g_surfaceCallback = {
  OnSurfaceCreated,
  OnSurfaceChanged,
  OnSurfaceDestroyed,
  DispatchTouchEvent,
};

napi_value Start(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc < 1 ||
      args[0] == nullptr) {
    LogError("start: missing options");
    return nullptr;
  }
  mermaid::StartOptions options;
  options.data_dir = GetStringProperty(env, args[0], "dataDir");
  options.save_dir = GetStringProperty(env, args[0], "saveDir");
  options.os_id = GetStringProperty(env, args[0], "osId");
  napi_value sidecut_value = nullptr;
  if (napi_get_named_property(env, args[0], "sidecut", &sidecut_value) == napi_ok && sidecut_value != nullptr) {
    int32_t sidecut = -1;
    if (napi_get_value_int32(env, sidecut_value, &sidecut) == napi_ok) {
      options.sidecut = sidecut;
    }
  }
  napi_value vsync_value = nullptr;
  if (napi_get_named_property(env, args[0], "vsync", &vsync_value) == napi_ok && vsync_value != nullptr) {
    bool vsync = true;
    if (napi_get_value_bool(env, vsync_value, &vsync) == napi_ok) {
      options.vsync = vsync;
    }
  }
  mermaid::EngineHost::Get().Start(options);
  return nullptr;
}

napi_value Stop(napi_env env, napi_callback_info info) {
  mermaid::EngineHost::Get().Stop();
  return nullptr;
}

napi_value Pause(napi_env env, napi_callback_info info) {
  mermaid::EngineHost::Get().Pause();
  return nullptr;
}

napi_value Resume(napi_env env, napi_callback_info info) {
  mermaid::EngineHost::Get().Resume();
  return nullptr;
}

napi_value SendKey(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr, nullptr};
  if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc < 2) {
    return nullptr;
  }
  int32_t key_code = 0;
  bool down = false;
  if (napi_get_value_int32(env, args[0], &key_code) != napi_ok ||
      napi_get_value_bool(env, args[1], &down) != napi_ok) {
    return nullptr;
  }
  mermaid::EngineHost::Get().SendKey(key_code, down);
  return nullptr;
}

napi_value GetState(napi_env env, napi_callback_info info) {
  napi_value result = nullptr;
  napi_create_int32(env, mermaid::EngineHost::Get().State(), &result);
  return result;
}

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
    {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"stop", nullptr, Stop, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pause", nullptr, Pause, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"resume", nullptr, Resume, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendKey", nullptr, SendKey, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"state", nullptr, GetState, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

  napi_value export_instance = nullptr;
  if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &export_instance) == napi_ok &&
      export_instance != nullptr) {
    OH_NativeXComponent *native_xcomponent = nullptr;
    if (napi_unwrap(env, export_instance, reinterpret_cast<void **>(&native_xcomponent)) == napi_ok &&
        native_xcomponent != nullptr) {
      OH_NativeXComponent_RegisterCallback(native_xcomponent, &g_surfaceCallback);
      OH_NativeXComponent_RegisterKeyEventCallback(native_xcomponent, OnKeyEvent);
      LogInfo("xcomponent callbacks registered");
    }
  }
  return exports;
}

napi_module g_module = {
  1,
  0,
  nullptr,
  Init,
  "artemishost",
  nullptr,
  {0},
};

} // namespace

extern "C" __attribute__((constructor)) void RegisterArtemisHostModule() {
  napi_module_register(&g_module);
}
