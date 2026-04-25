# OpsAI

OpsAI is an iPhone app for direct SSH operations with a user-configured AI assistant.

## Product direction

- No backend required
- User connects to servers directly from the device
- AI provider is configurable with OpenAI-compatible settings
- AI never executes commands automatically
- Every command draft requires explicit user approval before execution
- AI command drafting is shown progressively in a dedicated command composer instead of a generic chat box

## Current scope

This repository contains the initial SwiftUI app scaffold, local persistence, AI planning flow, approval-first terminal workbench, and a real password-based SSH connection layer for iOS.

## Tech stack

- SwiftUI
- XcodeGen
- `gaetanzanella/swift-ssh-client` on top of Apple `swift-nio-ssh`
- UserDefaults for non-secret local state
- Keychain wrapper for secrets
- GitHub Actions for macOS builds

## Local development

1. Install XcodeGen on macOS.
2. Run `xcodegen generate`.
3. Open the generated `OpsAI.xcodeproj`.
4. Build and run on iPhone simulator or device.

## Signing

Signed IPA packaging is prepared in `.github/workflows/ios-build.yml`. Add these GitHub repository secrets when signing is ready:

- `IOS_P12_BASE64`
- `IOS_P12_PASSWORD`
- `IOS_MOBILEPROVISION_BASE64`
- `IOS_TEAM_ID`
- `IOS_BUNDLE_ID`
- `IOS_PROFILE_NAME`
- `IOS_CERT_PEM_BASE64`
- `IOS_KEY_PEM_BASE64`

## Next build milestone

- Add private-key authentication
- Add streaming AI responses for live token-by-token command drafting
- Add host key verification and biometric unlock gates for secrets
