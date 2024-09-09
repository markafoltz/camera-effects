# Camera Effect Status: API

## Authors:

*   [bryantchandler@chromium.org](mailto:bryantchandler@chromium.org)
*   [mfoltz@chromium.org](mailto:mfoltz@chromium.org)

## Introduction

Camera effects implemented at the operating system level are becoming
increasingly common on macOS, Windows, and ChromeOS. This can cause issues for
video chat users. For example, if a user enables background blur on both their
OS and in a video chat application, it can strain their system resources and
cause the application's blur effect to malfunction. Additionally, users may
forget they have enabled background blur at the OS level, leading to confusion
when they are unable to disable it within a video chat application.

We propose addressing these issues by providing a way for Web applications to
detect the status of video effects applied by the OS or browser. Initially, it
focuses on background blur, but it is designed to accommodate additional effects
in the future (e.g. face framing, or lighting adjustment). This capability could
also be useful in other applications. For example, proctoring applications could
use it to detect and /request that users disable background blur to ensure
proper monitoring.

The proposed solution exposes the read-only effect state on MediaStreamTrack and
VideoFrameMetadata. This will enable Web developers to easily determine the
current state of the effect and provide event handlers for change detection.

## Goals

* Allow Web developers to easily access and monitor changes in platform blur.
* Enable Web developers to build new features that respond to changes in
    background blur.
* Provide a consistent and easy-to-use API for accessing platform effect state.

## Non-goals

* This API does not provide a way to control platform effects. That
    functionality may be exposed in a future API.
* This API does not attempt to polyfill effects in platforms/browsers that do
    not support them.
* This API doesn’t include all possible platform effects. More effects may be
   exposed as future extensions ofAPI.

## MediaStreamTrack

The effect has an associated `MediaEffect` property on the `MediaStreamTrack`
interface. The state of the effect can be obtained from the property. Any change
to the state fires an event on the effect object. The presence of the field can
also be used to detect if the platform/browser supports background blur.


```Javascript
const stream = await navigator.mediaDevices.getUserMedia({video: true});
const videoTrack = stream.getVideoTracks()[0];
if (videoTrack.backgroundBlur) {
  const effect = videoTrack.backgroundBlur;
  console.log("Background blur state:", effect.state);
  effect.addEventListener("change", (event) => {
    console.log("Background blur state changed:", event.target.state);
  });
}
```

## VideoFrameMetadata

The `VideoFrameMetadata` interface also exposes the effect state as a
property. This allows apps to know the state for every frame. This is important
for scenarios where the app must ensure user privacy by never sending an
unblurred frame off the user's device.


```Javascript
const transformer = new TransformStream({
    async transform(videoFrame, controller) {
      console.log("Background blur state:",
        videoFrame.metadata().backgroundBlur);
      controller.enqueue(videoFrame);
    },
  });

```

## Key scenarios

### Scenario 1

Displaying an indicator when background blur is enabled:

```Javascript
const stream = await navigator.mediaDevices.getUserMedia({video: true});
const videoTrack = stream.getVideoTracks()[0];
const blurIndicator = document.getElementById("blurIndicator");
videoTrack.addEventListener("change", (event) => {
  if (event.target.backgroundBlur) {
    blurIndicator.style.display = event.target.backgroundBlur.state === "enabled" ? "block" : "none";
  }
});
```
## Privacy Considerations

Exposing the effect state reveals some additional information about the user's
preference.  However, effect state and availability is gated behind the camera
permission. We believe that this increase of scope for the camera permission is
acceptable.

## Detailed design

### API

```
enum EffectState {
   "disabled",
   "enabled"
}

struct MediaEffectInfo {
  EffectState state;
}

partial dictionary VideoFrameMetadata {
  MediaEffectInfo backgroundBlur;
}

[Exposed=Window, SecureContext]
interface MediaEffect : EventTarget {
  attribute EventHandler onchange;
  readonly attribute EffectState state;
}

[Exposed=Window, SecureContext]
interface BlurEffect : MediaEffect {
}

partial interface MediaStreamTrack {
   // null means platform effect is not available 
   attribute BlurEffect? backgroundBlur;
}
```

### Event-based notifications

The change event is used to notify Web applications when the state of an effect
changes. This allows applications to respond to changes in real time, without
having to poll the effect state.

## Considered alternatives

### Exposing effect state as a boolean

An alternative design would be to expose the effect state as a boolean value,
rather than an enum. This would simplify the API, but the enum is more
expressive, and gives affordance for adding more states in the future.

### Effects as an array or map

In this approach, the effect names themselves would be defined in an enum (using
a map would still allow you to map to the enum effect state). There probably
wouldn’t be much benefit here, as JS already allows developers to iterate over
the child properties of an object. The downside of the array approach is that it
would make it harder to look at the state of specific effects a la carte. It
seems likely that in order to give users relevant information, a site will need
to look at the state of individual effects, and not just check if any effects
are enabled.


