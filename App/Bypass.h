#import <Foundation/Foundation.h>

/// Installs the "return YES" swizzle on LAContext, in-process.
///
/// This is the SAME hook as inject/FaceIDBypass.m, but compiled INTO the app so
/// we can demonstrate the attack on a real device without a jailbreak or Frida.
/// On a real device the Secure Enclave still protects the Keychain, so you can
/// see the naive vault fall while the secure vault holds the line.
void InstallFaceIDBypass(void);
