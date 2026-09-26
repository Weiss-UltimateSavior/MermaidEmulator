#pragma once

#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include <string>

namespace mermaid {

class OhosRenderer {
public:
  bool Init(void *window, bool vsync);
  bool UpdateSurface(void *window);
  void Shutdown();
  void SetStage(int stage_w, int stage_h, bool sidecut);
  void Clear();
  void Present();
  bool Ready() const { return ready_; }
  int Width() const { return width_; }
  int Height() const { return height_; }
  float StageX(float win_x) const;
  float StageY(float win_y) const;
  const std::string &LastError() const { return last_error_; }

private:
  EGLConfig config_ = nullptr;
  EGLDisplay display_ = EGL_NO_DISPLAY;
  EGLSurface surface_ = EGL_NO_SURFACE;
  EGLContext context_ = EGL_NO_CONTEXT;
  bool ready_ = false;
  int width_ = 0;
  int height_ = 0;
  float vp_x_ = 0.0f;
  float vp_y_ = 0.0f;
  float vp_w_ = 1.0f;
  float vp_h_ = 1.0f;
  int stage_w_ = 1280;
  int stage_h_ = 720;
  bool sidecut_ = false;
  bool vsync_ = true;
  std::string last_error_;
};

} // namespace mermaid
