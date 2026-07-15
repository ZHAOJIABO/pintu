# AGENTS.md

## Project Context

This project is an iOS app built with Flutter/Dart.

The product design source of truth is Figma:

- Figma file: [🐰 Pin](https://www.figma.com/design/LyCXmniTOMwVetmOesfQle/%F0%9F%90%B0-Pin?node-id=55-958&m=dev)

When working on this project, treat the Figma design as the visual and interaction specification. The user may provide specific component/page Figma links, Figma-generated Flutter code, color tokens, spacing values, typography values, asset references, and screenshots. Use those as the primary implementation reference.

## Core Requirements

- Use Flutter/Dart for app implementation.
- Build primarily for iOS, while keeping Flutter code portable unless a platform-specific iOS behavior is explicitly required.
- Match the Figma design as closely as possible, including layout, spacing, colors, typography, icon size, corner radius, shadows, states, and visual hierarchy.
- Prioritize responsive layouts that work across multiple iPhone models and screen sizes.
- Prefer drawing UI with Flutter code instead of relying on sliced images.
- Use image assets only when they are truly necessary, such as photos, complex illustrations, brand artwork, or assets that cannot reasonably be reproduced with Flutter widgets, CustomPainter, icons, gradients, or vector-like code.
- Do not invent a different design direction when Figma provides a clear target.
- Design and implement with future extensibility in mind.
- Keep backend integration in mind even though the backend is not available yet.

## Figma Implementation Rules

When a Figma link, screenshot, or generated Flutter code is provided:

- Inspect the provided design details before implementing.
- Treat Figma measurements, colors, typography, radii, opacity, and layout relationships as authoritative.
- Use Figma-generated Flutter code as a reference, not as blind copy-paste. Clean it up to fit the project's architecture and Flutter best practices while preserving the design.
- If Figma code uses absolute positioning, translate it into maintainable Flutter layout where possible, such as `Column`, `Row`, `Stack`, `Expanded`, `Flexible`, `LayoutBuilder`, `AspectRatio`, `Padding`, and constraints.
- Preserve visual fidelity even when improving code structure.
- If a design detail is ambiguous, infer from nearby Figma components and existing project patterns.
- If the ambiguity materially affects the UI, ask for clarification before making a large visual decision.

## Responsive Layout Requirements

Every screen and component should be designed for multiple iPhone sizes, including compact and large screens.

- Avoid hard-coding full-screen widths and heights unless they are derived from constraints.
- Use `MediaQuery`, `LayoutBuilder`, `SafeArea`, `AspectRatio`, `Flexible`, `Expanded`, and responsive constraints where appropriate.
- Respect iOS safe areas, including the notch, Dynamic Island, bottom home indicator, and keyboard.
- Ensure text does not overflow on smaller screens.
- Ensure buttons and touch targets remain usable on all supported sizes.
- Prefer scalable spacing rules over one-off magic numbers.
- Test mentally and, when possible, by running the app across multiple simulator sizes.
- Keep scroll behavior intentional. If content can exceed the viewport, use proper scroll views instead of allowing overflow.

## Code-Drawn UI Preference

Prefer Flutter-native UI construction:

- Use widgets, layout primitives, gradients, borders, shadows, `CustomPainter`, `ClipPath`, `DecoratedBox`, `Container`, `Icon`, and vector-capable approaches before introducing bitmap slices.
- Use package or system icons when they match the design.
- Use custom painters for simple shapes, decorative lines, charts, masks, or repeated visual motifs.
- Keep generated or hand-written drawing code readable and isolated in small widgets.
- Do not slice Figma frames into large static images just to reproduce layout.
- If an asset is necessary, keep it named clearly, sized appropriately, and documented by usage.

## Visual Fidelity Checklist

Before considering UI work complete, check:

- Colors match the provided Figma values.
- Typography matches family, size, weight, line height, and alignment as closely as the project allows.
- Spacing and padding match the Figma layout.
- Corner radius and border styles match.
- Shadows, blur, opacity, and gradients match.
- Icons and visual symbols match size, stroke, fill, and placement.
- Components behave correctly in default, pressed, disabled, selected, loading, empty, and error states when those states are relevant.
- The UI works on small and large iPhone screens.
- There is no clipped text, accidental overflow, or layout jump.

## Flutter Code Style

- Follow the existing project structure and naming conventions.
- Keep widgets small, composable, and readable.
- Prefer `const` constructors where possible.
- Avoid unnecessary rebuilds and heavy work inside `build`.
- Extract repeated design values into local constants, theme tokens, or reusable widgets when they are used more than once.
- Keep business logic separate from visual widgets where possible.
- Use clear widget names that describe product intent, not only visual appearance.
- Avoid broad refactors unless they are needed for the requested change.

## Extensibility And Backend Integration

The backend is not available yet, so frontend work should be prepared for future API integration without over-engineering.

### API Integration Requirements

When integrating a backend API, document and implement the interface contract explicitly before wiring it into the UI:

- Define the request input clearly, including endpoint, method, required and optional parameters, parameter types, validation rules, authentication requirements, and idempotency expectations where relevant.
- Define the response output clearly, including success payload fields, field types, nullable fields, pagination/cursor data, error codes/messages, and the UI behavior mapped to each result.
- Specify how every meaningful response state is presented: initial loading, refresh/loading more, success, empty data, recoverable error, unauthorized/expired session, and retry. Do not leave backend output without a defined presentation or interaction outcome.
- Keep API models, mapping, and error handling outside visual widgets where practical, so temporary mock data can be replaced without redesigning screens.
- Preserve the existing approved page design and styles when connecting APIs. Do not change layout, colors, typography, spacing, component hierarchy, or interaction design unless the API contract genuinely requires it or the user explicitly requests the visual change.
- Account for response speed and unreliable networks: avoid blocking the UI, show a design-consistent loading state when needed, set appropriate timeouts, support cancellation or stale-response protection where relevant, and prevent duplicate submissions/requests. Keep already available content visible during refresh whenever the product flow allows it.

- Separate UI, state, data models, and data access logic where practical.
- Do not hard-code mock data deep inside visual widgets.
- Keep mock data easy to replace with real API responses later.
- Prefer typed models for structured data that will likely come from the backend.
- Design data shapes with likely backend contracts in mind, but avoid inventing unnecessary complexity before APIs exist.
- Encapsulate temporary local/mock data behind small services, repositories, providers, controllers, or clearly named helper layers when the feature size justifies it.
- Keep loading, empty, error, and retry states in mind for screens that will eventually depend on network data.
- Avoid coupling UI components directly to one temporary data source.
- Name fields and models clearly so they can map naturally to future backend DTOs or API responses.
- If a backend assumption affects product behavior, call it out explicitly instead of hiding it in code.
- When using placeholder data, make it obvious that it is temporary.
- Avoid blocking UI implementation just because backend APIs are missing; build realistic frontend states that can be wired up later.

## Theming And Design Tokens

- Use Figma-provided colors and typography values.
- If the project already has theme tokens, map Figma values into the existing theme system.
- If no theme system exists, introduce small, focused constants only when useful.
- Avoid scattering raw color values and text styles across many files.
- Keep token names semantic when possible, such as `primaryText`, `surface`, `accent`, `danger`, `cardBorder`, or `mutedText`.
- Do not replace exact Figma colors with approximate colors unless the user approves.

## Asset Policy

- Use assets sparingly.
- Do not export entire screens or large UI sections as images.
- Prefer SVG/vector-style assets for icons when available and compatible with the project.
- Use raster images for photos, complex illustrations, or Figma assets that are impractical to recreate in code.
- Optimize asset size and avoid unnecessarily large files.
- Keep assets organized using the existing project conventions.

## iOS-Specific Quality

- Respect iOS interaction conventions.
- Keep touch targets comfortable, generally at least 44x44 points where practical.
- Handle keyboard appearance cleanly.
- Ensure scroll views, bottom bars, sheets, and overlays respect safe areas.
- Avoid Android-only visual patterns unless the design explicitly uses them.
- Use Cupertino-style behavior where the project or design calls for it, but do not force Cupertino widgets if the Figma design is custom.

## Working Process

When implementing a requested screen or component:

1. Read the relevant existing Flutter files first.
2. Review the provided Figma link, screenshot, generated Flutter code, colors, and measurements.
3. Identify existing reusable widgets, themes, assets, and patterns.
4. Implement the smallest coherent change that matches the design.
5. Prefer clean responsive Flutter layout over brittle absolute positioning.
6. Run formatting and relevant checks when practical.
7. If UI was changed, verify the result on at least one compact and one larger iPhone size when possible.
8. Summarize what changed and how it was verified.

## Communication Preferences

- Respond in Chinese unless the user asks otherwise.
- Be direct and specific.
- When making UI decisions, explain the reason briefly.
- If Figma and existing app behavior conflict, call out the conflict before choosing.
- If a detail is missing from Figma or the provided code, make a reasonable assumption and state it.
- Do not silently change unrelated behavior or unrelated files.

## Things To Avoid

- Do not implement iOS UI with another framework unless explicitly requested.
- Do not use large screenshot slices as a substitute for real Flutter UI.
- Do not ignore safe areas or small-screen behavior.
- Do not hard-code layout in a way that only works for one device size.
- Do not casually approximate colors, typography, or spacing when exact Figma values are available.
- Do not introduce unnecessary dependencies for simple UI drawing.
- Do not rewrite project architecture for a single component.
- Do not make broad visual changes beyond the requested Figma scope.
