(function () {
  const ZXing = window.ZXing;
  const scanners = new Map();

  function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async function waitForHostElement(hostId, timeoutMs = 4000) {
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      const host = document.getElementById(hostId);
      if (host) {
        return host;
      }

      await wait(50);
    }

    throw new Error('Scanner host element was not found.');
  }

  function createEmptySnapshot() {
    return {
      started: false,
      torchAvailable: false,
      torchEnabled: false,
      detectionVersion: 0,
      detectedValue: '',
      errorVersion: 0,
      errorMessage: '',
    };
  }

  function getState(scannerId) {
    return scanners.get(scannerId);
  }

  function getSnapshot(scannerId) {
    const state = getState(scannerId);
    if (!state) {
      return createEmptySnapshot();
    }

    return {
      started: state.started,
      torchAvailable: state.torchAvailable,
      torchEnabled: state.torchEnabled,
      detectionVersion: state.detectionVersion,
      detectedValue: state.detectedValue,
      errorVersion: state.errorVersion,
      errorMessage: state.errorMessage,
    };
  }

  function setError(state, error) {
    const message =
      typeof error === 'string'
        ? error
        : error && typeof error.message === 'string'
          ? error.message
          : String(error || 'Scanner error');

    state.errorVersion += 1;
    state.errorMessage = message;
    console.error('[shopScanScanner]', message);
  }

  function clearError(state) {
    state.errorMessage = '';
  }

  function getDetectedValue(result) {
    if (!result) {
      return '';
    }

    try {
      if (typeof result.getText === 'function') {
        return String(result.getText() || '').trim();
      }
    } catch (_) {}

    return String(result.text || '').trim();
  }

  async function updateTorchCapabilities(state) {
    const stream = state.stream;
    if (!(stream instanceof MediaStream)) {
      state.torchAvailable = false;
      state.torchEnabled = false;
      return;
    }

    const [track] = stream.getVideoTracks();
    if (!track || typeof track.getCapabilities !== 'function') {
      state.torchAvailable = false;
      state.torchEnabled = false;
      return;
    }

    const capabilities = track.getCapabilities();
    state.torchAvailable = Boolean(capabilities && capabilities.torch);

    if (!state.torchAvailable) {
      state.torchEnabled = false;
    }
  }

  function disposeState(state) {
    if (!state) {
      return;
    }

    try {
      state.reader && state.reader.reset();
    } catch (_) {}

    if (state.video) {
      try {
        state.video.pause();
      } catch (_) {}
      try {
        state.video.srcObject = null;
      } catch (_) {}
    }

    if (state.stream instanceof MediaStream) {
      for (const track of state.stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
    }

    if (state.host) {
      state.host.innerHTML = '';
    }
  }

  async function startDecodeLoop(reader, video, callback) {
    const attempts = [
      {
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          focusMode: { ideal: 'continuous' },
        },
      },
      {
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      },
      { audio: false, video: true },
    ];

    let lastError;

    for (const constraints of attempts) {
      try {
        await reader.decodeFromConstraints(constraints, video, callback);
        return;
      } catch (error) {
        lastError = error;
        try {
          reader.reset();
        } catch (_) {}
      }
    }

    throw lastError || new Error('Unable to start the camera.');
  }

  function start(scannerId, hostId) {
    stop(scannerId);

    const state = {
      host: null,
      video: null,
      reader: null,
      stream: null,
      started: false,
      torchAvailable: false,
      torchEnabled: false,
      detectionVersion: 0,
      detectedValue: '',
      errorVersion: 0,
      errorMessage: '',
    };

    scanners.set(scannerId, state);

    (async () => {
      try {
        const host = await waitForHostElement(hostId);
        if (getState(scannerId) !== state) {
          return;
        }

        if (!ZXing || !ZXing.BrowserMultiFormatReader) {
          throw new Error('ZXing runtime is not available on this page.');
        }

        const video = document.createElement('video');
        video.setAttribute('autoplay', 'true');
        video.setAttribute('muted', 'true');
        video.setAttribute('playsinline', 'true');
        video.muted = true;
        video.playsInline = true;
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.objectFit = 'cover';

        host.innerHTML = '';
        host.appendChild(video);

        const reader = new ZXing.BrowserMultiFormatReader();
        if ('timeBetweenDecodingAttempts' in reader) {
          reader.timeBetweenDecodingAttempts = 45;
        }

        state.host = host;
        state.video = video;
        state.reader = reader;

        await startDecodeLoop(reader, video, function (result, error) {
          if (result) {
            const detectedValue = getDetectedValue(result);
            if (detectedValue && detectedValue !== state.detectedValue) {
              state.detectedValue = detectedValue;
              state.detectionVersion += 1;
              clearError(state);
              console.info('[shopScanScanner] detected barcode:', detectedValue);
            }
          }

          if (!state.started && video.readyState >= 2) {
            state.started = true;
            clearError(state);
          }

          if (!error) {
            return;
          }

          if (
            error instanceof ZXing.NotFoundException ||
            error instanceof ZXing.ChecksumException ||
            error instanceof ZXing.FormatException
          ) {
            return;
          }

          setError(state, error);
        });

        if (getState(scannerId) !== state) {
          disposeState(state);
          return;
        }

        state.stream = video.srcObject;
        state.started = true;
        await updateTorchCapabilities(state);
        clearError(state);
        console.info('[shopScanScanner] camera started');
      } catch (error) {
        if (getState(scannerId) !== state) {
          return;
        }

        setError(state, error);
      }
    })();

    return getSnapshot(scannerId);
  }

  function stop(scannerId) {
    const state = getState(scannerId);
    if (!state) {
      return;
    }

    disposeState(state);
    scanners.delete(scannerId);
  }

  function toggleTorch(scannerId) {
    const state = getState(scannerId);
    if (!state || !(state.stream instanceof MediaStream)) {
      throw new Error('Scanner is not ready yet.');
    }

    const [track] = state.stream.getVideoTracks();
    if (!track || typeof track.getCapabilities !== 'function') {
      throw new Error('Flashlight is not available on this device.');
    }

    const capabilities = track.getCapabilities();
    if (!capabilities || !capabilities.torch) {
      throw new Error('Flashlight is not available on this device.');
    }

    const nextTorchEnabled = !state.torchEnabled;
    Promise.resolve(
      track.applyConstraints({
        advanced: [{ torch: nextTorchEnabled }],
      })
    )
      .then(() => {
        state.torchEnabled = nextTorchEnabled;
      })
      .catch((error) => {
        setError(state, error);
      });

    return nextTorchEnabled;
  }

  window.shopScanScanner = {
    start,
    stop,
    toggleTorch,
    snapshot: getSnapshot,
  };
})();