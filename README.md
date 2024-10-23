# Camera Effect Status: API

## Authors:

- [bryantchandler@google.com](mailto:bryantchandler@google.com)
- [mfoltz@google.com](mailto:mfoltz@google.com)

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

The proposed solution exposes the read-only effect state on
`VideoFrameMetadata`. This will enable Web developers to easily determine the
current state of the effect.

## Goals

- Allow Web developers to easily access and monitor changes in platform blur.
- Enable Web developers to build new features that respond to changes in
  background blur.
- Provide a consistent and easy-to-use API for accessing platform effect state.

## Non-goals

- This API does not provide a way to control platform effects.
- This API does not attempt to polyfill effects in platforms/browsers that do
  not support them.
- This API doesn’t include all possible platform effects. More effects may be
  exposed as future extensions of the API.

## VideoFrameMetadata

The `VideoFrameMetadata` interface also exposes the effect state as a property.
This allows apps to know the state for every frame. This is important for
scenarios where the app must ensure user privacy by never sending an un-blurred
frame off the user's device.

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
const trackProcessor = new MediaStreamTrackProcessor({ track: videoTrack });
const trackGenerator = new MediaStreamTrackGenerator({ kind: "video" });

const transformer = new TransformStream({
  async transform(videoFrame, controller) {
    blurIndicator.style.display =
      videoFrame.backgroundBlur === "enabled" ? "block" : "none";

    controller.enqueue(videoFrame);
  },
});

trackProcessor.readable
  .pipeThrough(transformer)
  .pipeTo(trackGenerator.writable);

const processedStream = new MediaStream();

videoTrack.addEventListener("change", (event) => {
  if (event.target.backgroundBlur) {
    blurIndicator.style.display =
      event.target.backgroundBlur.state === "enabled" ? "block" : "none";
  }
});
```

## Privacy Considerations

Exposing the effect state reveals some additional information about the user's
preference. However, effect state and availability is gated behind the camera
permission. We believe that this increase of scope for the camera permission is
acceptable.

## Detailed design

### API

```webidl
dictionary MediaEffectInfo {
  readonly boolean isEnabled;
}

partial dictionary VideoFrameMetadata {
  MediaEffectInfo backgroundBlur;
}
```

## Architectural Considerations

One set of guidelines used by the W3C to assess architectural fit of features on
the Web are the [TAG design
principles](https://w3ctag.github.io/design-principles/).

Below are brief assessments of how this proposal fits with some of those
principles.

### 1.1 Put user needs first (Priority of Constituencies)

We believe that exposing blur information to applications improves the user
experience for camera users, by preventing duplicate and interfering effects
from being applied by platforms and applications, and helping minimize confusion
about where users can control effects (apps vs. platforms).

### 2.1. Prefer simple solutions

Our proposal does not allow applications to control the blur state. As discussed
in [Explain interaction with
constraints](https://github.com/markafoltz/camera-effects/issues/4), this adds
significant complexity for users, developers, and browser implementers. It also
does not require constraints, which add an additional layer of complexity as
blur can influence camera enumeration.

On the other hand, we are adding properties to `VideoFrameMetadata`, which does
add more complexity to the API surface and implementation. We chose
`VideoFrameMetadata`, because it is the most accurate and privacy-preserving
method for conveying the state (by attaching it to individual camera frames).

### 9.1 Don’t expose unnecessary information about devices

We believe we are exposing minimal information necessary for sites to accomplish
their goals, i.e. prevent duplicate effects, hide unnecessary controls, and
provide guidance to users to adjust their OS or browser blur setting if needed.

### 9.2 Use care when exposing APIs for selecting or enumerating devices

Our proposal does not impact device enumeration nor does it impact the use of
constraints to select devices that are blur capable or have blur enabled.

### 9.4. Be proactive about safety

Platform (i.e., OS-level) background blur is currently a global status that is
tied to a specific camera or browser and thus is shared among origins. This is a
constraint of the current blur implementations, and may be relaxed in the future
as platforms become more capable and allow applications to apply effects on
individual streams from the same camera.

Unfortunately, enforcing exclusive access by origin (as suggested by TAG) to
hide blur status would break legitimate use cases like participating in a live
stream using one Web application while also video conferencing in another Web
application using the same camera.

## Comparison with MediaStreamTrack backgroundBlur controls

The [Media Capture and Streams](https://w3c.github.io/mediacapture-main/)
specification exposes background blur settings on a `MediaStreamTrack` as
[capabilities](https://w3c.github.io/mediacapture-main/getusermedia.html#dom-mediatrackcapabilities-backgroundblur)
and as a
[setting](https://w3c.github.io/mediacapture-main/getusermedia.html#dom-mediatracksettings-backgroundblur).

### Capabilities

This is a tri-state value that has three possible outcomes:

- `false` means that blur is not currently supported by the platform
- `true` means that blur is supported and cannot be turned off
- [`false`, `true`] means that blur is supported, and can be turned on or off

This goes above and beyond what is included in our proposal. Our proposal does
not expose the level of application control for blur state.

We have concerns about whether applications should be allowed to control
platform blur directly, especially with the current generation of effects
implementations; in these, changing the effects for one site changes it for
others that are also consuming the same camera stream.

Also, we are considering extensions to this proposal. These extensions include:

- In scenarios where the application cannot disable blur directly, whether the
  browser can be asked to prompt the user to do so;
- Information indicating whether blur was supported by the browser, the OS, or
  both.

Any of these new features, if implemented, would require a different API shape
than what is currently in the spec. Therefore, the current pattern is not very
good for extensibility along these lines.

### Setting

This exposes the current blur state as a boolean. Our proposal uses a dictionary,
which is preferred for extensibility.

### Summary

Features of our proposal missing from current spec:

- Per-frame information about effect state
- Extensibility for future ways applications could interact with effects.

Features of current spec missing from our proposal:

- Ability to know whether effects can be turned on or off.

## Considered alternatives

### Effect state as an enum

```webidl
enum EffectState {
   "disabled",
   "enabled"
}

dictionary MediaEffectInfo {
  readonly EffectState state;
}
```

This would use an enum instead of `isEnabled`, but we can't envision a scenario
where we would need more than two options, so it could be simplified to a
boolean. If more information is needed in the future, then it can be added to
`MediaEffectInfo` as a separate field.

### Effects as an array or map

In this approach, the effect names themselves would be defined in an enum (using
a map would still allow you to map to the enum effect state). There probably
wouldn’t be much benefit here, as JS already allows developers to iterate over
the child properties of an object. The downside of the array approach is that it
would make it harder to look at the state of specific effects a la carte. It
seems likely that in order to give users relevant information, a site will need
to look at the state of individual effects, and not just check if any effects
are enabled.
