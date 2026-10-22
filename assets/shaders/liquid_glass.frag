#version 460 core
#include <flutter/runtime_effect.glsl>

// The engine supplies the input texture and its physical dimensions.
uniform vec2 uTextureSize;
uniform sampler2D uBackdrop;
uniform float uDpr;
uniform vec2 uOrigin;
uniform vec2 uPanelSize;
uniform float uBend;

out vec4 fragColor;

void main() {
  vec2 pixel = FlutterFragCoord().xy;
  vec2 p = pixel / uDpr - uOrigin;
  float r = uPanelSize.y * 0.5;
  vec2 centered = p - uPanelSize * 0.5;
  float straight = max(uPanelSize.x * 0.5 - r, 0.0);
  vec2 closest = vec2(clamp(centered.x, -straight, straight), 0.0);
  vec2 radial = centered - closest;
  float radialLength = max(length(radial), 0.0001);
  float inside = r - radialLength;
  float bevel = min(12.0, r * 0.42);
  float rim = 1.0 - clamp(inside / bevel, 0.0, 1.0);
  // Only the rounded bevel bends the backdrop. The clear central face stays
  // sharp, unlike a frosted gaussian pane. Sampling inward avoids dark edges.
  float bend = uBend * rim * rim * (3.0 - 2.0 * rim);
  vec2 samplePoint = p - radial / radialLength * bend;
  samplePoint = clamp(samplePoint, vec2(1.0), uPanelSize - vec2(1.0));
  vec2 uv = (samplePoint + uOrigin) * uDpr / uTextureSize;
  #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
  #endif
  fragColor = texture(uBackdrop, clamp(uv, vec2(0.0), vec2(1.0)));
}
