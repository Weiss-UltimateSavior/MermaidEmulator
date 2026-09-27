
Graphics._stretchHeight = function() {
    if (Utils.isMobileDevice()) {
        return document.documentElement.clientHeight;
    } else {
        return window.innerHeight;
    }
};
Graphics._defaultStretchMode = function() {
    return true;
};
WebAudio._createContext = function() {
    try {
        var AC = window.AudioContext || window.webkitAudioContext;
        try {
            this._context = new AC({ sampleRate: 44100, latencyHint: 'playback' });
        } catch (e) {
            this._context = new AC();
        }
    } catch (e) {
        this._context = null;
    }
};
