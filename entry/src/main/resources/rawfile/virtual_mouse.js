/* 虚拟鼠标（RPG Maker MV/MZ）：移植自 TyranorNext VirtualMouseLayer.kt + __tyranor_mouse.js。
 * 原生层用 Android View 覆盖 WebView；此处改为注入页面内的 DOM 图层，手势语义一致：
 *  - 手柄：左侧悬浮圆钮，可拖动（位置持久化），单击切换光标模式。
 *  - 光标模式：单指拖动=相对移动光标（hover 跟随）；单指快速点按=左键；
 *    双指上下滑动=滚轮；单指长按 350ms=右键；双指快速点按=右键。
 *  - 光标关闭时除手柄区域一律放行（触屏零干扰）；触屏手柄/网页 UI 始终放行。
 * 合成事件经 window.__tnMouse 派发（坐标为 CSS 像素）。
 */
;(function () {
  "use strict"
  if (window.__tnVirtualMouse) return
  window.__tnVirtualMouse = true;

  /* ================= 合成鼠标事件 API（window.__tnMouse） ================= */
  (function () {
    if (window.__tnMouse) return

    function hitElement(x, y) {
      var cx = Math.min(Math.max(x, 0), (window.innerWidth || 1) - 1)
      var cy = Math.min(Math.max(y, 0), (window.innerHeight || 1) - 1)
      try { return document.elementFromPoint(cx, cy) } catch (e) { return null }
    }

    function fire(constructor, init) {
      var el = hitElement(init.clientX, init.clientY) || document.body || document.documentElement
      if (!el) return
      var ev = new constructor(init.type, init)
      // MZ 的 TouchInput 读 event.pageX/pageY，合成事件上恒为 undefined
      // → Graphics.pageToCanvasX(undefined)=NaN → 命中失效。手动补齐（页面无滚动）。
      try {
        Object.defineProperty(ev, "pageX", { value: init.clientX || 0 })
        Object.defineProperty(ev, "pageY", { value: init.clientY || 0 })
      } catch (e) { /* 忽略 */ }
      el.dispatchEvent(ev)
    }

    var pendingClick = null

    function mouseEvent(type, x, y, button) {
      fire(MouseEvent, {
        type: type, clientX: x, clientY: y,
        screenX: x, screenY: y,
        button: button || 0,
        buttons: type === "mousedown" ? (button === 2 ? 2 : 1) : 0,
        bubbles: true, cancelable: true
      })
    }

    window.__tnMouse = {
      move: function (x, y) { mouseEvent("mousemove", x, y, 0) },
      down: function (x, y, button) { mouseEvent("mousedown", x, y, button) },
      up: function (x, y, button) { mouseEvent("mouseup", x, y, button) },
      /* 左键单击 = down + 按住 ~50ms + up + click：同帧 down+up 会让
       * Window_Message 的 isRepeated() 失效（对话永不推进），须跨帧。 */
      click: function (x, y) {
        var self = this
        this.down(x, y, 0)
        if (pendingClick) { clearTimeout(pendingClick) }
        pendingClick = setTimeout(function () {
          pendingClick = null
          self.up(x, y, 0)
          fire(MouseEvent, { type: "click", clientX: x, clientY: y, button: 0, bubbles: true, cancelable: true })
        }, 50)
      },
      rclick: function (x, y) {
        this.down(x, y, 2)
        this.up(x, y, 2)
        fire(MouseEvent, {
          type: "contextmenu", clientX: x, clientY: y,
          button: 2, buttons: 0, bubbles: true, cancelable: true
        })
      },
      wheel: function (deltaY, x, y) {
        fire(WheelEvent, {
          type: "wheel", deltaX: 0, deltaY: deltaY, deltaZ: 0, deltaMode: 0,
          clientX: x, clientY: y, bubbles: true, cancelable: true
        })
        var el = hitElement(x, y)
        var depth = 0
        while (el && el !== document.body && el !== document.documentElement && depth++ < 8) {
          if (el.scrollHeight > el.clientHeight + 1) {
            var oy = ""
            try { oy = getComputedStyle(el).overflowY } catch (e) { oy = "" }
            if (oy === "auto" || oy === "scroll" || oy === "overlay") {
              el.scrollTop += deltaY
              return
            }
          }
          el = el.parentElement
        }
      },
      cancel: function () {
        if (pendingClick) { clearTimeout(pendingClick); pendingClick = null }
        this.up(0, 0, 0)
        this.up(0, 0, 2)
      }
    }
  })()

  /* ================= 图层与手势状态机 ================= */
  var LONG_PRESS_MS = 350
  var TWO_FINGER_TAP_MS = 300
  var WHEEL_SENS = 4
  var CURSOR_SENS = 1.5
  var FLUSH_INTERVAL_MS = 16
  var HANDLE_R = 23
  var SLOP = 8

  var STATE_IDLE = 0
  var STATE_HANDLE = 1
  var STATE_PENDING = 2
  var STATE_DRAG = 3
  var STATE_WHEEL = 4
  var STATE_COOLDOWN = 5
  var STATE_CONSUMED = 6

  function vw() { return window.innerWidth || 1 }
  function vh() { return window.innerHeight || 1 }
  function now() { return Date.now() }

  var handle = document.createElement("div")
  handle.style.cssText = "position:fixed;z-index:2147483000;border-radius:50%;box-sizing:border-box;" +
    "display:flex;align-items:center;justify-content:center;touch-action:none;" +
    "user-select:none;-webkit-user-select:none;background:rgba(255,255,255,0.16);" +
    "border:1px solid rgba(255,255,255,0.45);"
  handle.innerHTML = '<svg width="58%" height="58%" viewBox="0 0 24 30" fill="none" stroke="#fff" ' +
    'stroke-width="2.4" stroke-linecap="round"><rect x="4" y="2" width="16" height="26" rx="8"/>' +
    '<line x1="12" y1="4.5" x2="12" y2="14"/><line x1="5" y1="14" x2="19" y2="14"/></svg>'

  var cursor = document.createElement("div")
  cursor.style.cssText = "position:fixed;z-index:2147483001;pointer-events:none;display:none;"
  cursor.innerHTML = '<svg width="12.4" height="19" viewBox="0 0 10.3 15.8">' +
    '<path d="M0 0 L0 13.6 L3.3 10.6 L5.6 15.8 L7.7 14.8 L5.6 9.9 L10.3 9.6 Z" ' +
    'fill="#ffffff" stroke="#141414" stroke-width="0.9" stroke-linejoin="round"/></svg>'
  var cursorPath = cursor.querySelector("path")

  document.body.appendChild(handle)
  document.body.appendChild(cursor)

  var hnx = parseFloat(localStorage.getItem("tn_mouse_hnx") || "")
  if (!isFinite(hnx)) hnx = 0.055
  var hny = parseFloat(localStorage.getItem("tn_mouse_hny") || "")
  if (!isFinite(hny)) hny = 0.48
  var cnx = 0.5
  var cny = 0.4
  var hx = hnx * vw()
  var hy = hny * vh()

  var active = false
  var state = STATE_IDLE
  var pid1 = -1
  var pid2 = -1
  var p1x = 0; var p1y = 0
  var p2x = 0; var p2y = 0
  var sx = 0; var sy = 0
  var lastCx = 0; var lastCy = 0
  var moved = false
  var handleDrag = false
  var hox = 0; var hoy = 0
  var downAt = 0
  var twoFingerAt = 0
  var pendingMoveX = null
  var pendingMoveY = 0
  var pendingWheel = 0
  var flushTimer = -1
  var longPressTimer = -1

  function layout() {
    hx = Math.min(Math.max(hnx * vw(), HANDLE_R), vw() - HANDLE_R)
    hy = Math.min(Math.max(hny * vh(), HANDLE_R), vh() - HANDLE_R)
    handle.style.width = (HANDLE_R * 2) + "px"
    handle.style.height = (HANDLE_R * 2) + "px"
    handle.style.left = (hx - HANDLE_R) + "px"
    handle.style.top = (hy - HANDLE_R) + "px"
    cursor.style.left = (cnx * vw()) + "px"
    cursor.style.top = (cny * vh()) + "px"
  }

  function padBusy() {
    var tp = window.__touchPad
    return !!(tp && (tp.isEditMode() || tp.isPreview()))
  }

  function refreshVisibility() {
    var busy = padBusy()
    handle.style.display = busy ? "none" : "flex"
    cursor.style.display = (!busy && active) ? "block" : "none"
  }

  function inHandle(x, y) {
    return Math.hypot(x - hx, y - hy) <= HANDLE_R + 6
  }

  function isPadTarget(t) {
    var n = t
    while (n) {
      if (n.__pad) return true
      n = n.parentElement
    }
    return false
  }

  function isGameTarget(t) {
    if (!t) return false
    var tag = t.tagName
    return tag === "CANVAS" || tag === "VIDEO" || tag === "BODY" || tag === "HTML"
  }

  function findTouch(list, id) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].identifier === id) return list[i]
    }
    return null
  }

  function consume(ev) {
    ev.stopPropagation()
    ev.preventDefault()
  }

  function setActive(on) {
    active = on
    handle.style.background = on ? "rgba(70,154,255,0.45)" : "rgba(255,255,255,0.16)"
    if (on) {
      cursor.style.display = "block"
      pendingMoveX = cnx * vw()
      pendingMoveY = cny * vh()
      scheduleFlush()
    } else {
      cursor.style.display = "none"
    }
  }

  function flushNow() {
    if (flushTimer >= 0) {
      clearTimeout(flushTimer)
      flushTimer = -1
    }
    if (pendingMoveX !== null) {
      window.__tnMouse.move(pendingMoveX, pendingMoveY)
      pendingMoveX = null
    }
    if (pendingWheel !== 0) {
      window.__tnMouse.wheel(pendingWheel, cnx * vw(), cny * vh())
      pendingWheel = 0
    }
  }

  function scheduleFlush() {
    if (flushTimer < 0) {
      flushTimer = setTimeout(flushNow, FLUSH_INTERVAL_MS)
    }
  }

  function onLongPress() {
    if (state === STATE_PENDING && !moved) {
      state = STATE_CONSUMED
      window.__tnMouse.rclick(cnx * vw(), cny * vh())
    }
  }

  function resetGesture() {
    clearTimeout(longPressTimer)
    clearTimeout(flushTimer)
    flushTimer = -1
    state = STATE_IDLE
    pid1 = -1
    pid2 = -1
    pendingMoveX = null
    pendingWheel = 0
  }

  document.addEventListener("touchstart", function (ev) {
    for (var i = 0; i < ev.changedTouches.length; i++) {
      var t = ev.changedTouches[i]
      if (pid1 === -1) {
        if (inHandle(t.clientX, t.clientY) && !isPadTarget(t.target)) {
          consume(ev)
          pid1 = t.identifier
          p1x = t.clientX; p1y = t.clientY
          sx = p1x; sy = p1y
          lastCx = p1x; lastCy = p1y
          moved = false
          handleDrag = false
          downAt = now()
          state = STATE_HANDLE
          hox = p1x - hx
          hoy = p1y - hy
          continue
        }
        if (!active || isPadTarget(t.target) || !isGameTarget(t.target)) {
          continue
        }
        consume(ev)
        pid1 = t.identifier
        p1x = t.clientX; p1y = t.clientY
        sx = p1x; sy = p1y
        lastCx = p1x; lastCy = p1y
        moved = false
        downAt = now()
        state = STATE_PENDING
        clearTimeout(longPressTimer)
        longPressTimer = setTimeout(onLongPress, LONG_PRESS_MS)
        continue
      }
      if (pid2 === -1 && (state === STATE_PENDING || state === STATE_DRAG)) {
        consume(ev)
        pid2 = t.identifier
        p2x = t.clientX; p2y = t.clientY
        clearTimeout(longPressTimer)
        lastCx = (p1x + p2x) / 2
        lastCy = (p1y + p2y) / 2
        twoFingerAt = now()
        state = STATE_WHEEL
        continue
      }
      if (state !== STATE_IDLE) {
        consume(ev)
      }
    }
  }, { capture: true, passive: false })

  document.addEventListener("touchmove", function (ev) {
    if (state === STATE_IDLE || pid1 === -1) return
    var t1 = findTouch(ev.changedTouches, pid1)
    var t2 = pid2 !== -1 ? findTouch(ev.changedTouches, pid2) : null
    if (!t1 && !t2) return
    consume(ev)
    if (t1) { p1x = t1.clientX; p1y = t1.clientY }
    if (t2) { p2x = t2.clientX; p2y = t2.clientY }
    if (state === STATE_HANDLE) {
      if (Math.hypot(p1x - sx, p1y - sy) > SLOP) handleDrag = true
      if (handleDrag) {
        hx = Math.min(Math.max(p1x - hox, HANDLE_R), vw() - HANDLE_R)
        hy = Math.min(Math.max(p1y - hoy, HANDLE_R), vh() - HANDLE_R)
        handle.style.left = (hx - HANDLE_R) + "px"
        handle.style.top = (hy - HANDLE_R) + "px"
      }
    } else if (state === STATE_PENDING) {
      if (!moved && Math.hypot(p1x - sx, p1y - sy) > SLOP) {
        moved = true
        clearTimeout(longPressTimer)
        state = STATE_DRAG
      }
    } else if (state === STATE_DRAG) {
      cnx = Math.min(Math.max(cnx + (p1x - lastCx) * CURSOR_SENS / vw(), 0), 1)
      cny = Math.min(Math.max(cny + (p1y - lastCy) * CURSOR_SENS / vh(), 0), 1)
      cursor.style.left = (cnx * vw()) + "px"
      cursor.style.top = (cny * vh()) + "px"
      pendingMoveX = cnx * vw()
      pendingMoveY = cny * vh()
      scheduleFlush()
    } else if (state === STATE_WHEEL) {
      var cxNow = (p1x + p2x) / 2
      var cyNow = (p1y + p2y) / 2
      var dy = cyNow - lastCy
      if (Math.hypot(cxNow - lastCx, dy) > SLOP) moved = true
      pendingWheel += -dy * WHEEL_SENS
      cursorPath.setAttribute("fill", "#FFD34D")
      scheduleFlush()
    }
    lastCx = p1x; lastCy = p1y
    if (pid2 !== -1) {
      lastCx = (p1x + p2x) / 2
      lastCy = (p1y + p2y) / 2
    }
  }, { capture: true, passive: false })

  document.addEventListener("touchend", function (ev) {
    if (state === STATE_IDLE) return
    var up1 = findTouch(ev.changedTouches, pid1)
    var up2 = pid2 !== -1 ? findTouch(ev.changedTouches, pid2) : null
    if (!up1 && !up2) {
      if (ev.changedTouches.length > 0) consume(ev)
      return
    }
    consume(ev)
    if (state === STATE_WHEEL) {
      flushNow()
      cursorPath.setAttribute("fill", "#ffffff")
      if (!moved && now() - twoFingerAt < TWO_FINGER_TAP_MS) {
        window.__tnMouse.rclick(cnx * vw(), cny * vh())
      }
      state = STATE_COOLDOWN
      if (up2) {
        pid2 = -1
      } else {
        pid1 = pid2
        pid2 = -1
      }
      if (pid1 === -1) state = STATE_IDLE
      return
    }
    if (state === STATE_COOLDOWN) {
      if (up1) pid1 = -1
      if (up2) pid2 = -1
      if (pid1 === -1) state = STATE_IDLE
      return
    }
    if (up2) {
      pid2 = -1
      return
    }
    if (up1) {
      clearTimeout(longPressTimer)
      var quick = !moved && state === STATE_PENDING && now() - downAt < LONG_PRESS_MS
      if (state === STATE_HANDLE && !handleDrag) {
        setActive(!active)
      } else if (quick && active) {
        flushNow()
        window.__tnMouse.click(cnx * vw(), cny * vh())
      } else if (active) {
        flushNow()
      }
      if (state === STATE_HANDLE && handleDrag) {
        hnx = hx / vw()
        hny = hy / vh()
        try {
          localStorage.setItem("tn_mouse_hnx", String(hnx))
          localStorage.setItem("tn_mouse_hny", String(hny))
        } catch (e) { /* 忽略 */ }
      }
      state = STATE_IDLE
      pid1 = -1
      pid2 = -1
    }
  }, { capture: true, passive: false })

  document.addEventListener("touchcancel", function (ev) {
    if (state === STATE_IDLE) return
    consume(ev)
    resetGesture()
    window.__tnMouse.cancel()
  }, { capture: true, passive: false })

  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") {
      resetGesture()
      window.__tnMouse.cancel()
    }
  })

  window.addEventListener("resize", function () {
    layout()
  })

  layout()
  refreshVisibility()
  setInterval(refreshVisibility, 400)
})()
