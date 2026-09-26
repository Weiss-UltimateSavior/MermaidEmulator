#include "host/ohos_renderer.h"

#include <hilog/log.h>

#include <dlfcn.h>

namespace mermaid {

namespace {

constexpr unsigned int kLogDomain = 0x4D45;
constexpr const char *kLogTag = "ArtemisHost";

void LogInfo(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_INFO, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

void LogError(const std::string &message) {
  OH_LOG_Print(LOG_APP, LOG_ERROR, kLogDomain, kLogTag, "%{public}s", message.c_str());
}

} // namespace

bool OhosRenderer::Init(void *window, bool vsync) {
  Shutdown();
  vsync_ = vsync;
  if (window == nullptr) {
    last_error_ = "window is null";
    return false;
  }
  display_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (display_ == EGL_NO_DISPLAY) {
    last_error_ = "eglGetDisplay failed";
    return false;
  }
  if (eglInitialize(display_, nullptr, nullptr) != EGL_TRUE) {
    last_error_ = "eglInitialize failed";
    return false;
  }
  const EGLBoolean bound = eglBindAPI(EGL_OPENGL_ES_API);
  LogInfo(std::string("eglBindAPI(ES) ") + (bound == EGL_TRUE ? "ok" : "failed"));
  static const EGLint kConfigMinimal[] = {
    EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_NONE
  };
  static const EGLint kConfigRgba[] = {
    EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_RED_SIZE, 8,
    EGL_GREEN_SIZE, 8,
    EGL_BLUE_SIZE, 8,
    EGL_ALPHA_SIZE, 8,
    EGL_NONE
  };
  static const EGLint kConfigRgbaDepth[] = {
    EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_RED_SIZE, 8,
    EGL_GREEN_SIZE, 8,
    EGL_BLUE_SIZE, 8,
    EGL_ALPHA_SIZE, 8,
    EGL_DEPTH_SIZE, 24,
    EGL_STENCIL_SIZE, 8,
    EGL_NONE
  };
  const EGLint *config_sets[] = { kConfigMinimal, kConfigRgba, kConfigRgbaDepth };
  const EGLint context_attrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
  for (int index = 0; index < 3 && surface_ == EGL_NO_SURFACE; ++index) {
    EGLConfig config = nullptr;
    EGLint config_count = 0;
    if (eglChooseConfig(display_, config_sets[index], &config, 1, &config_count) != EGL_TRUE ||
        config_count < 1) {
      LogInfo("egl config set " + std::to_string(index) + " not available");
      continue;
    }
    EGLContext context = eglCreateContext(display_, config, EGL_NO_CONTEXT, context_attrs);
    if (context == EGL_NO_CONTEXT) {
      LogInfo("egl context set " + std::to_string(index) + " failed");
      continue;
    }
    while (eglGetError() != EGL_SUCCESS) {
    }
    EGLSurface surface = eglCreateWindowSurface(display_, config,
                                                reinterpret_cast<EGLNativeWindowType>(window), nullptr);
    if (surface == EGL_NO_SURFACE) {
      LogError("egl surface set " + std::to_string(index) + " failed err=" +
               std::to_string(eglGetError()));
      eglDestroyContext(display_, context);
      continue;
    }
    context_ = context;
    surface_ = surface;
    config_ = config;
  }
  if (surface_ == EGL_NO_SURFACE) {
    last_error_ = "eglCreateWindowSurface failed window=" +
                  std::to_string(reinterpret_cast<uintptr_t>(window));
    return false;
  }
  if (eglMakeCurrent(display_, surface_, surface_, context_) != EGL_TRUE) {
    last_error_ = "eglMakeCurrent failed";
    return false;
  }
  eglSwapInterval(display_, vsync_ ? 1 : 0);
  EGLint width = 0;
  EGLint height = 0;
  eglQuerySurface(display_, surface_, EGL_WIDTH, &width);
  eglQuerySurface(display_, surface_, EGL_HEIGHT, &height);
  width_ = width;
  height_ = height;
  glViewport(0, 0, width_, height_);
  ready_ = true;
  const char *gl_version = reinterpret_cast<const char *>(glGetString(GL_VERSION));
  const char *gl_renderer = reinterpret_cast<const char *>(glGetString(GL_RENDERER));
  LogInfo("egl ready " + std::to_string(width_) + "x" + std::to_string(height_) +
          " gl=" + (gl_version != nullptr ? std::string(gl_version) : "?") +
          " renderer=" + (gl_renderer != nullptr ? std::string(gl_renderer) : "?"));
  return true;
}

bool OhosRenderer::UpdateSurface(void *window) {
  if (!ready_ || display_ == EGL_NO_DISPLAY || context_ == EGL_NO_CONTEXT || config_ == nullptr ||
      window == nullptr) {
    return false;
  }
  eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  if (surface_ != EGL_NO_SURFACE) {
    eglDestroySurface(display_, surface_);
    surface_ = EGL_NO_SURFACE;
  }
  EGLSurface new_surface = eglCreateWindowSurface(
      display_, config_, reinterpret_cast<EGLNativeWindowType>(window), nullptr);
  if (new_surface == EGL_NO_SURFACE) {
    last_error_ = "eglCreateWindowSurface failed on resize err=" +
                  std::to_string(eglGetError());
    return false;
  }
  surface_ = new_surface;
  if (eglMakeCurrent(display_, surface_, surface_, context_) != EGL_TRUE) {
    last_error_ = "eglMakeCurrent failed on resize";
    return false;
  }
  eglSwapInterval(display_, vsync_ ? 1 : 0);
  EGLint width = 0;
  EGLint height = 0;
  eglQuerySurface(display_, surface_, EGL_WIDTH, &width);
  eglQuerySurface(display_, surface_, EGL_HEIGHT, &height);
  width_ = width;
  height_ = height;
  SetStage(stage_w_, stage_h_, sidecut_);
  LogInfo("egl surface resized " + std::to_string(width_) + "x" + std::to_string(height_));
  return true;
}

void OhosRenderer::Shutdown() {
  if (display_ != EGL_NO_DISPLAY) {
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(display_, surface_);
    }
    if (context_ != EGL_NO_CONTEXT) {
      eglDestroyContext(display_, context_);
    }
    eglTerminate(display_);
  }
  display_ = EGL_NO_DISPLAY;
  surface_ = EGL_NO_SURFACE;
  context_ = EGL_NO_CONTEXT;
  config_ = nullptr;
  ready_ = false;
  width_ = 0;
  height_ = 0;
  LogInfo("egl shutdown");
}

void OhosRenderer::SetStage(int stage_w, int stage_h, bool sidecut) {
  stage_w_ = stage_w;
  stage_h_ = stage_h;
  sidecut_ = sidecut;
  if (!ready_ || stage_w <= 0 || stage_h <= 0) {
    return;
  }
  const float scale_x = static_cast<float>(width_) / stage_w;
  const float scale_y = static_cast<float>(height_) / stage_h;
  const float scale = sidecut ? (scale_x > scale_y ? scale_x : scale_y)
                              : (scale_x < scale_y ? scale_x : scale_y);
  vp_w_ = stage_w * scale;
  vp_h_ = stage_h * scale;
  vp_x_ = (width_ - vp_w_) * 0.5f;
  vp_y_ = (height_ - vp_h_) * 0.5f;
  glViewport(static_cast<GLint>(vp_x_), static_cast<GLint>(vp_y_),
             static_cast<GLsizei>(vp_w_), static_cast<GLsizei>(vp_h_));
  LogInfo("viewport " + std::to_string(static_cast<int>(vp_w_)) + "x" +
          std::to_string(static_cast<int>(vp_h_)) + " at " +
          std::to_string(static_cast<int>(vp_x_)) + "," +
          std::to_string(static_cast<int>(vp_y_)));
}

float OhosRenderer::StageX(float win_x) const {
  if (vp_w_ <= 0.0f) {
    return win_x;
  }
  return (win_x - vp_x_) * stage_w_ / vp_w_;
}

float OhosRenderer::StageY(float win_y) const {
  if (vp_h_ <= 0.0f) {
    return win_y;
  }
  return (win_y - vp_y_) * stage_h_ / vp_h_;
}

void OhosRenderer::Clear() {
  if (!ready_) {
    return;
  }
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
}

void OhosRenderer::Present() {
  if (!ready_) {
    return;
  }
  if (eglSwapBuffers(display_, surface_) != EGL_TRUE) {
    LogError("eglSwapBuffers failed");
  }
}

} // namespace mermaid
