var TyranoPlayer = (function() {
    var TyranoPlayer = function(storage_url) {
        if (!(this instanceof TyranoPlayer)) {
            return new TyranoPlayer(storage_url);
        }
        this.storage_url = storage_url;
    }
    var p = TyranoPlayer.prototype;
    p.pauseAllAudio = function() {
        try {
            if (typeof TYRANO === 'undefined' || !TYRANO.kag || !TYRANO.kag.tmp) return;
            var bgm_objs = TYRANO.kag.tmp.map_bgm;
            var se_objs = TYRANO.kag.tmp.map_se;
            for (var key in bgm_objs) { bgm_objs[key].pause(); }
            for (var key in se_objs) { se_objs[key].pause(); }
        } catch(e) { console.log("pauseAllAudio failed: " + e); }
    }
    p.resumeAllAudio = function() {
        try {
            if (typeof TYRANO === 'undefined' || !TYRANO.kag || !TYRANO.kag.tmp) return;
            var bgm_objs = TYRANO.kag.tmp.map_bgm;
            var se_objs = TYRANO.kag.tmp.map_se;
            if (bgm_objs[TYRANO.kag.stat.current_bgm]) {
                bgm_objs[TYRANO.kag.stat.current_bgm].play();
            } else if (bgm_objs[0]) {
                bgm_objs[0].play();
            }
        } catch(e) { console.log("resumeAllAudio failed: " + e); }
    }
    return TyranoPlayer;
})();
var _tyrano_player = new TyranoPlayer("");
if (typeof tyrano !== 'undefined' && tyrano.base) {
tyrano.base.fitBaseSize = function(width, height) {
    $(".tyrano_base").css("position","absolute");
    var that = this;
    var view_width = $.getViewPort().width;
    var view_height = $.getViewPort().height;
    var width_f = view_width / width;
    var height_f = view_height / height;
    var scale_f = 0;
    var screen_ratio = this.tyrano.kag.config.ScreenRatio;
    if (screen_ratio == "fix") {
        if (width_f > height_f) { scale_f = height_f; }
        else { scale_f = width_f; }
        this.tyrano.kag.tmp.base_scale = scale_f;
        setTimeout(function() {
            $(".tyrano_base").css("transform-origin", "0 0");
            $(".tyrano_base").css({ margin: 0 });
            var w = Math.abs(parseInt(window.innerWidth) - parseInt(that.tyrano.kag.config.scWidth * scale_f)) / 2;
            var h = Math.abs(parseInt(window.innerHeight) - parseInt(that.tyrano.kag.config.scHeight * scale_f)) / 2;
            if (width_f > height_f) { $(".tyrano_base").css("left", w + "px"); $(".tyrano_base").css("top", "0px"); }
            else { $(".tyrano_base").css("left", "0px"); $(".tyrano_base").css("top", h + "px"); }
            $(".tyrano_base").css("transform", "scale(" + scale_f + ")");
            if (parseInt(view_width) < parseInt(w)) { if (scale_f < 1) { window.scrollTo(w, h); } }
        }, 100);
    } else if (screen_ratio == "fit") {
        setTimeout(function() {
            $(".tyrano_base").css("transform", "scaleX(" + width_f + ") scaleY(" + height_f + ")");
            window.scrollTo(width, height);
        }, 100);
    }
};
}
$.setStorage = function(key, val, type) {
    if ("appJsInterface" in window) {
        try { appJsInterface.setStorage(key, escape(JSON.stringify(val))); return; } catch(e) { console.log(e); }
    }
    window.tyrano_save[key] = encodeURIComponent(JSON.stringify(val));
}
$.getStorage = function(key, type) {
    if ("appJsInterface" in window) {
        try {
            var json_str = appJsInterface.getStorage(key);
            if (json_str == "") return null;
            return unescape(json_str);
        } catch(e) { console.log(e); }
    }
    if (!window.tyrano_save[key] || window.tyrano_save[key] == "") return null;
    return decodeURIComponent(window.tyrano_save[key]);
}
$.openWebFromApp = function(url) {
    if ("appJsInterface" in window) { try { appJsInterface.openUrl(url); return; } catch(e) { console.log(e); } }
    window.open(url);
}
$.userenv = function() { return 'pc'; }
