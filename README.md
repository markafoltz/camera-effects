# Camera Effect Status: API

## Authors:

*   [bryantchandler@google.com](mailto:bryantchandler@chromium.org)
*   [mfoltz@google.com](mailto:mfoltz@chromium.org)

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

```js
const stream = await navigator.mediaDevices.getUserMedia({ video: true });
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

```js
const transformer = new TransformStream({
  async transform(videoFrame, controller) {
    console.log("Background blur state:", videoFrame.metadata().backgroundBlur);
    controller.enqueue(videoFrame);
  },
});
```

## Key scenarios

### Scenario 1

Displaying an indicator when background blur is enabled:

```js
const stream = await navigator.mediaDevices.getUserMedia({ video: true });
const videoTrack = stream.getVideoTracks()[0];
const blurIndicator = document.getElementById("blurIndicator");
videoTrack.addEventListener("change", (event) => {
  if (event.target.backgroundBlur) {
    blurIndicator.style.display =
      event.target.backgroundBlur.state === "enabled" ? "block" : "none";
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

```webidl
enum EffectState {
   "disabled",
   "enabled"
}

dictionary MediaEffectInfo {
  readonly EffectState state;
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

## Comparison with MediaStreamTrack backgroundBlur controls

The Media Capture and Streams Extensions specification exposes
background blur settings on a `MediaStreamTrack` as
[capabilities](https://w3c.github.io/mediacapture-main/getusermedia.html#dom-mediatrackcapabilities-backgroundblur))
and as a [setting](https://w3c.github.io/mediacapture-main/getusermedia.html#dom-mediatracksettings-backgroundblur).

### Capability

This is a tri-state value that has three possible outcomes:
- `false` means that blur is not currently supported by the platform
- `true` means that blur is supported and cannot be turned off
- [`false`, `true`] means that blur is supported, and can be turned on or off

This goes above and beyond what is included in our proposal.  Our proposal does
not expose the level of application control for blur state.

We have concerns about whether applications should be allowed to control
platform blur directly, especially with the current generation of effects
implementations; in these, changing the effects for one site changes it for
others that are also consuming the same camera stream. 

Also, we are considering extensions to this proposal.  These extensions include:

- An event that would let applications know if blur support has changed
  dynamically;
- In scenarios where the application cannot disable blur directly, whether the
  browser can be asked to prompt the user to do so;
- Information indicating whether blur was supported by the browser, the OS, or
  both.

Any of these new features, if implemented, would require a different API shape
than what is currently in the spec.  Therefore, the current pattern is not very
good for extensibility along these lines.

### Setting

This exposes the current blur state as a boolean.  Our proposal uses an enum,
which is preferred for extensibility.

Our proposal goes beyond this and adds an event for when the blur status
changes.  The current spec does not provide applications a way to know when the
current blur state has changed.

### Summary

Features of our proposal missing from current spec:

- Events for effects status changes.
- Extensibility for future ways applications could interact with effects.

Features of current spec missing from our proposal:

- Ability to know whether effects can be turned on or off.

Below is an [extension of the current proposal]() that would add this feature.

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

### Exposing ability for applications to turn blur on or off

If we wished to expose this ability, the API could be extended with booleans
indicating the allowed state transitions.

```webidl
partial dictionary MediaEffectInfo {
  boolean canEnable = false;
  boolean canDisable = false;
}
```

This version lists the states to which that the Web application is allowed to
transition.  For example if the application is allowed to enable but not disable
blur, `allowedStates` would contain `"enabled"`.  If no state changes are
allowed, then `allowedStates` is empty.

```webidl
partial dictionary MediaEffectInfo {
  required sequence<EffectState> allowedStates;
}
```
